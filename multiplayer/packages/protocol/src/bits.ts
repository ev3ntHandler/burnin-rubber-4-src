/** Minimal growable binary writer/reader with LEB128 varints, used by the binary profile. */

export class Writer {
  private buf: Uint8Array;
  private view: DataView;
  private pos = 0;

  constructor(capacity = 512) {
    this.buf = new Uint8Array(capacity);
    this.view = new DataView(this.buf.buffer);
  }

  private ensure(n: number): void {
    if (this.pos + n <= this.buf.length) return;
    let cap = this.buf.length;
    while (cap < this.pos + n) cap *= 2;
    const next = new Uint8Array(cap);
    next.set(this.buf.subarray(0, this.pos));
    this.buf = next;
    this.view = new DataView(this.buf.buffer);
  }

  u8(v: number): this {
    this.ensure(1);
    this.view.setUint8(this.pos, v & 0xff);
    this.pos += 1;
    return this;
  }

  u16(v: number): this {
    this.ensure(2);
    this.view.setUint16(this.pos, v & 0xffff);
    this.pos += 2;
    return this;
  }

  i16(v: number): this {
    this.ensure(2);
    this.view.setInt16(this.pos, clampInt(v, -32768, 32767));
    this.pos += 2;
    return this;
  }

  u32(v: number): this {
    this.ensure(4);
    this.view.setUint32(this.pos, v >>> 0);
    this.pos += 4;
    return this;
  }

  i32(v: number): this {
    this.ensure(4);
    this.view.setInt32(this.pos, clampInt(v, -2147483648, 2147483647));
    this.pos += 4;
    return this;
  }

  f32(v: number): this {
    this.ensure(4);
    this.view.setFloat32(this.pos, v);
    this.pos += 4;
    return this;
  }

  /** Unsigned LEB128. */
  varuint(v: number): this {
    let n = Math.max(0, Math.floor(v));
    do {
      let byte = n & 0x7f;
      n = Math.floor(n / 128);
      if (n > 0) byte |= 0x80;
      this.u8(byte);
    } while (n > 0);
    return this;
  }

  /** Signed LEB128 (zig-zag). */
  varint(v: number): this {
    const n = Math.floor(v);
    const zig = n < 0 ? -n * 2 - 1 : n * 2;
    return this.varuint(zig);
  }

  string(s: string): this {
    const bytes = utf8Encode(typeof s === 'string' ? s : '');
    this.varuint(bytes.length);
    this.bytes(bytes);
    return this;
  }

  bytes(b: Uint8Array): this {
    this.ensure(b.length);
    this.buf.set(b, this.pos);
    this.pos += b.length;
    return this;
  }

  raw(): Uint8Array {
    return this.buf.subarray(0, this.pos);
  }

  toBytes(): Uint8Array {
    return this.buf.slice(0, this.pos);
  }
}

export class Reader {
  private view: DataView;
  private pos = 0;
  public readonly bytes: Uint8Array;

  constructor(bytes: Uint8Array) {
    this.bytes = bytes;
    this.view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  }

  get remaining(): number {
    return this.bytes.length - this.pos;
  }

  u8(): number {
    this.need(1);
    return this.view.getUint8(this.pos++);
  }

  u16(): number {
    this.need(2);
    const v = this.view.getUint16(this.pos);
    this.pos += 2;
    return v;
  }

  i16(): number {
    this.need(2);
    const v = this.view.getInt16(this.pos);
    this.pos += 2;
    return v;
  }

  u32(): number {
    this.need(4);
    const v = this.view.getUint32(this.pos);
    this.pos += 4;
    return v;
  }

  i32(): number {
    this.need(4);
    const v = this.view.getInt32(this.pos);
    this.pos += 4;
    return v;
  }

  f32(): number {
    this.need(4);
    const v = this.view.getFloat32(this.pos);
    this.pos += 4;
    return v;
  }

  varuint(): number {
    let result = 0;
    let shift = 0;
    for (;;) {
      const byte = this.u8();
      result += (byte & 0x7f) * Math.pow(2, shift);
      if ((byte & 0x80) === 0) break;
      shift += 7;
      if (shift > 49) throw new RangeError('varuint too long');
    }
    return result;
  }

  varint(): number {
    const zig = this.varuint();
    return zig % 2 === 0 ? zig / 2 : -(zig + 1) / 2;
  }

  string(): string {
    const len = this.varuint();
    this.need(len);
    const slice = this.bytes.subarray(this.pos, this.pos + len);
    this.pos += len;
    return utf8Decode(slice);
  }

  byteArray(len: number): Uint8Array {
    this.need(len);
    const slice = this.bytes.slice(this.pos, this.pos + len);
    this.pos += len;
    return slice;
  }

  private need(n: number): void {
    if (this.pos + n > this.bytes.length) throw new RangeError('unexpected end of message');
  }
}

function clampInt(v: number, min: number, max: number): number {
  if (!Number.isFinite(v)) return 0;
  const n = Math.round(v);
  return n < min ? min : n > max ? max : n;
}

/** Dependency-free UTF-8 helpers so the same module runs in Node and in the browser. */
export function utf8Encode(s: string): Uint8Array {
  const out: number[] = [];
  for (let i = 0; i < s.length; i++) {
    let cp = s.codePointAt(i) as number;
    if (cp > 0xffff) i++;
    if (cp < 0x80) out.push(cp);
    else if (cp < 0x800) out.push(0xc0 | (cp >> 6), 0x80 | (cp & 0x3f));
    else if (cp < 0x10000) out.push(0xe0 | (cp >> 12), 0x80 | ((cp >> 6) & 0x3f), 0x80 | (cp & 0x3f));
    else
      out.push(
        0xf0 | (cp >> 18),
        0x80 | ((cp >> 12) & 0x3f),
        0x80 | ((cp >> 6) & 0x3f),
        0x80 | (cp & 0x3f),
      );
  }
  return Uint8Array.from(out);
}

export function utf8Decode(b: Uint8Array): string {
  let out = '';
  let i = 0;
  while (i < b.length) {
    const c = b[i++];
    let cp: number;
    if (c < 0x80) cp = c;
    else if (c < 0xe0) cp = ((c & 0x1f) << 6) | (b[i++] & 0x3f);
    else if (c < 0xf0) cp = ((c & 0x0f) << 12) | ((b[i++] & 0x3f) << 6) | (b[i++] & 0x3f);
    else
      cp =
        ((c & 0x07) << 18) |
        ((b[i++] & 0x3f) << 12) |
        ((b[i++] & 0x3f) << 6) |
        (b[i++] & 0x3f);
    out += String.fromCodePoint(cp);
  }
  return out;
}
