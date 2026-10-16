"""
Patch map name in war3map.w3i, in-place (same technique as war3map.j patch)
"""
import sys, os, struct, zlib
sys.path.insert(0, r'C:\Users\57864\AppData\Local\DoubaoWork\User Data\sandbox_runtime\bases\d0ace100fdff5b2d247847aca1e3d83b\python\Lib\site-packages')
from mpyq import MPQArchive

src = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'
dst = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'

with open(src, 'rb') as f:
    raw = bytearray(f.read())

mpq_off = raw.find(b'MPQ\x1a')
tmp_mpq = r'D:\dota\DOTA69AI\scripts\temp_w3i.mpq'
with open(tmp_mpq, 'wb') as f:
    f.write(raw[mpq_off:])

archive = MPQArchive(tmp_mpq, listfile=False)
header = archive.header

# Find war3map.w3i
h = archive.get_hash_table_entry('war3map.w3i')
block_idx = h.block_table_index
b = archive.block_table[block_idx]
print(f"w3i block: offset={b.offset}, arch={b.archived_size}, uncomp={b.size}, flags=0x{b.flags:08X}")

# Read original w3i data
orig_w3i = archive.read_file('war3map.w3i')
print(f"Original w3i: {len(orig_w3i)} bytes")

# Find "Dota英雄守护达拉然" in the data
old_name = 'Dota英雄守护达拉然'.encode('utf-8')
new_name = '达拉然0.1'.encode('utf-8')
print(f"Old name bytes: {len(old_name)}, New name bytes: {len(new_name)}")

pos = orig_w3i.find(old_name)
print(f"Old name found at offset: {pos}")

# Replace
new_w3i = orig_w3i[:pos] + new_name + orig_w3i[pos+len(old_name):]
print(f"New w3i: {len(new_w3i)} bytes (was {len(orig_w3i)})")

# Now we need to write this back into the MPQ in-place
# But the size changed! Let's check: old was 26 bytes, new is 28 bytes
# Difference: +2 bytes. That's a problem for in-place.

# Actually, let's check if the new compressed data fits in original archived_size
# w3i is compressed (flags=0x80000200)
if b.flags & 0x00000200:
    # Compressed - need to recompress
    sector_size = 512 << header['sector_size_shift']
    num_sectors = (len(new_w3i) + sector_size - 1) // sector_size
    
    sector_offsets = []
    sector_blobs = []
    offset_table_size = (num_sectors + 1) * 4
    cur = offset_table_size
    for i in range(num_sectors):
        s = i * sector_size
        e = min(s + sector_size, len(new_w3i))
        sector = new_w3i[s:e]
        comp = zlib.compress(sector, 9)
        if len(comp) < len(sector):
            blob = b'\x02' + comp
        else:
            blob = sector
        sector_offsets.append(cur)
        sector_blobs.append(blob)
        cur += len(blob)
    sector_offsets.append(cur)
    
    offset_table = struct.pack(f'<{num_sectors+1}I', *sector_offsets)
    new_compressed = offset_table + b''.join(sector_blobs)
    print(f"New compressed: {len(new_compressed)} bytes (original archived: {b.archived_size})")
    
    if len(new_compressed) > b.archived_size:
        print("ERROR: new compressed data is bigger than original!")
        sys.exit(1)
    
    # Write new data at original offset
    data_abs_offset = mpq_off + b.offset
    raw[data_abs_offset:data_abs_offset + len(new_compressed)] = new_compressed
    # Zero pad
    pad_size = b.archived_size - len(new_compressed)
    if pad_size > 0:
        raw[data_abs_offset + len(new_compressed):data_abs_offset + b.archived_size] = b'\x00' * pad_size
    
    # Update block table
    block_table_abs = mpq_off + header['block_table_offset']
    bt_size = header['block_table_entries'] * 16
    enc_bt = bytes(raw[block_table_abs:block_table_abs + bt_size])
    block_key = archive._hash('(block table)', 'TABLE')
    dec_bt = bytearray(archive._decrypt(enc_bt, block_key))
    
    entry_off = block_idx * 16
    struct.pack_into('<4I', dec_bt, entry_off,
                     b.offset, len(new_compressed), len(new_w3i), b.flags)
    
    def mpq_encrypt(data, key, enc_table):
        seed1 = key
        seed2 = 0xEEEEEEEE
        result = bytearray()
        for i in range(len(data) // 4):
            seed2 = (seed2 + enc_table[0x400 + (seed1 & 0xFF)]) & 0xFFFFFFFF
            pt = struct.unpack_from("<I", data, i*4)[0]
            ct = (pt ^ ((seed1 + seed2) & 0xFFFFFFFF)) & 0xFFFFFFFF
            seed1 = (((~seed1 << 0x15) + 0x11111111) | (seed1 >> 0x0B)) & 0xFFFFFFFF
            seed2 = (pt + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
            result += struct.pack("<I", ct)
        return bytes(result)
    
    new_enc_bt = mpq_encrypt(dec_bt, block_key, archive.encryption_table)
    raw[block_table_abs:block_table_abs + bt_size] = new_enc_bt
    
    with open(dst, 'wb') as f:
        f.write(raw)
    print(f"Written: {dst}")
    
    # Verify
    vmpq = r'D:\dota\DOTA69AI\scripts\temp_verify_w3i.mpq'
    with open(dst, 'rb') as f:
        vraw = f.read()
    voff = vraw.find(b'MPQ\x1a')
    with open(vmpq, 'wb') as f:
        f.write(vraw[voff:])
    va = MPQArchive(vmpq, listfile=False)
    vdata = va.read_file('war3map.w3i')
    new_pos = vdata.find('达拉然后边'.encode('utf-8'))
    print(f"Verify: new name at offset {new_pos}")
    print(f"Context: {vdata[pos:pos+40]}")
