"""
Patch w3i map name by relocating it to the free space left over from war3map.j patch.
The war3map.j in-place patch left ~15KB of zero-padded free space. We put the new
w3i (uncompressed, SINGLE_UNIT) there and update the block table entry.
"""
import sys, os, struct, zlib
sys.path.insert(0, r'C:\Users\57864\AppData\Local\DoubaoWork\User Data\sandbox_runtime\bases\d0ace100fdff5b2d247847aca1e3d83b\python\Lib\site-packages')
from mpyq import MPQArchive

src = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'

with open(src, 'rb') as f:
    raw = bytearray(f.read())

mpq_off = raw.find(b'MPQ\x1a')
tmp_mpq = r'D:\dota\DOTA69AI\scripts\temp_relocate.mpq'
with open(tmp_mpq, 'wb') as f:
    f.write(raw[mpq_off:])

archive = MPQArchive(tmp_mpq, listfile=False)
header = archive.header

# Find war3map.w3i
h = archive.get_hash_table_entry('war3map.w3i')
w3i_block_idx = h.block_table_index
w3i_block = archive.block_table[w3i_block_idx]
print(f"Original w3i: offset={w3i_block.offset}, arch={w3i_block.archived_size}, uncomp={w3i_block.size}, flags=0x{w3i_block.flags:08X}")

# Find war3map.j block to get the free space location
h_j = archive.get_hash_table_entry('war3map.j')
j_block_idx = h_j.block_table_index
j_block = archive.block_table[j_block_idx]
print(f"war3map.j: offset={j_block.offset}, arch={j_block.archived_size}, uncomp={j_block.size}")

# Free space starts right after the new war3map.j compressed data
# We know from previous patch: new_compressed size = 1682695, original archived = 1697746
# Free space starts at j_block.offset + j_block.archived_size (the actual new compressed size)
# But wait - j_block.archived_size was already updated to 1682695 by patch5.
# The free space is at j_block.offset + j_block.archived_size, and extends for ~15KB
free_space_start = j_block.offset + j_block.archived_size
free_space_abs = mpq_off + free_space_start
print(f"Free space starts at MPQ offset: {free_space_start} (file offset: {free_space_abs})")

# Read original w3i and modify the name
orig_w3i = archive.read_file('war3map.w3i')
old_name = 'Dota英雄守护达拉然'.encode('utf-8')
new_name = '达拉然0.1测试版'.encode('utf-8')
pos = orig_w3i.find(old_name)
print(f"Old name at w3i offset {pos}")
new_w3i = orig_w3i[:pos] + new_name + orig_w3i[pos+len(old_name):]
print(f"New w3i size: {len(new_w3i)} bytes")

# Write new w3i as UNCOMPRESSED SINGLE_UNIT at free space
# Flags: EXISTS | SINGLE_UNIT = 0x81000000
# SINGLE_UNIT means no sector table, raw data directly
new_w3i_flags = 0x81000000

# Write data at free space
raw[free_space_abs:free_space_abs + len(new_w3i)] = new_w3i
print(f"Wrote new w3i ({len(new_w3i)} bytes) at file offset {free_space_abs}")

# Now update block table: w3i entry points to new location
block_table_abs = mpq_off + header['block_table_offset']
bt_size = header['block_table_entries'] * 16
enc_bt = bytes(raw[block_table_abs:block_table_abs + bt_size])
block_key = archive._hash('(block table)', 'TABLE')
dec_bt = bytearray(archive._decrypt(enc_bt, block_key))

# Update w3i entry
entry_off = w3i_block_idx * 16
struct.pack_into('<4I', dec_bt, entry_off,
                 free_space_start,      # new offset (MPQ-relative)
                 len(new_w3i),           # archived size = uncompressed size
                 len(new_w3i),           # uncompressed size
                 new_w3i_flags)         # EXISTS | SINGLE_UNIT
print(f"Updated block entry {w3i_block_idx}: offset={free_space_start}, size={len(new_w3i)}, flags=0x{new_w3i_flags:08X}")

# Re-encrypt block table
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

# Write output
with open(src, 'wb') as f:
    f.write(raw)
print(f"\nWritten: {src}")

# Verify
vmpq = r'D:\dota\DOTA69AI\scripts\temp_verify_final.mpq'
with open(src, 'rb') as f:
    vraw = f.read()
voff = vraw.find(b'MPQ\x1a')
with open(vmpq, 'wb') as f:
    f.write(vraw[voff:])
va = MPQArchive(vmpq, listfile=False)
vw3i = va.read_file('war3map.w3i')
vpos = vw3i.find('达拉然'.encode('utf-8'))
print(f"\nVerify: new map name at w3i offset {vpos}")
print(f"Context: {vw3i[vpos:vpos+30]}")

# Also verify war3map.j still works
vj = va.read_file('war3map.j')
print(f"war3map.j still readable: {len(vj)} bytes")
