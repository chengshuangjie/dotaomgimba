"""Patch war3map.j inside a .w3x MPQ using mpyq's own crypto."""
import struct, zlib, os, sys
from io import BytesIO

# Reuse mpyq's encryption table and hash functions
sys.path.insert(0, r'C:\Users\57864\AppData\Local\DoubaoWork\User Data\sandbox_runtime\bases\d0ace100fdff5b2d247847aca1e3d83b\python\Lib\site-packages')
from mpyq import MPQArchive

# Open the source MPQ (skip listfile since it may be missing)
# w3x has 512-byte HM3W header before MPQ - extract MPQ part first
src = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-latest.w3x'
dst = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'
new_j = r'D:\dota\DOTA69AI\src\war3map.j'

# Read the w3x, split off HM3W header
with open(src, 'rb') as f:
    w3x_data = f.read()
mpq_offset = w3x_data.find(b'MPQ\x1a')
hm3w_header = w3x_data[:mpq_offset]
mpq_data = w3x_data[mpq_offset:]
print(f"HM3W header: {len(hm3w_header)} bytes, MPQ starts at {mpq_offset}")

# Write temp MPQ file for mpyq
tmp_mpq = r'D:\dota\DOTA69AI\scripts\temp_src.mpq'
with open(tmp_mpq, 'wb') as f:
    f.write(mpq_data)

# Open with mpyq (MPQ starts at offset 0 now)
archive = MPQArchive(tmp_mpq, listfile=False)
header = archive.header
print(f"MPQ offset: {header['offset']}")
print(f"Hash table entries: {header['hash_table_entries']}")
print(f"Block table entries: {header['block_table_entries']}")

# Find war3map.j in hash table
hash_entry = archive.get_hash_table_entry('war3map.j')
if hash_entry is None:
    print("war3map.j not found!")
    sys.exit(1)
block_idx = hash_entry.block_table_index
print(f"war3map.j block index: {block_idx}")
block_entry = archive.block_table[block_idx]
print(f"Old block: offset={block_entry.offset}, archived={block_entry.archived_size}, uncomp={block_entry.size}, flags=0x{block_entry.flags:08X}")

# Read new war3map.j
with open(new_j, 'rb') as f:
    new_data = f.read()
print(f"New war3map.j: {len(new_data)} bytes")

# Build compressed sectors
sector_shift = header['sector_size_shift']
sector_size = 512 << sector_shift
num_sectors = (len(new_data) + sector_size - 1) // sector_size
print(f"Sector size: {sector_size}, sectors: {num_sectors}")

# Build sector offset table + compressed sectors
sector_offsets = []
sector_blobs = []
cur = 0
for i in range(num_sectors):
    start = i * sector_size
    end = min(start + sector_size, len(new_data))
    sector = new_data[start:end]
    # Compress with zlib (MPQ compression type 2 = zlib)
    comp = zlib.compress(sector, 9)
    if len(comp) < len(sector):
        blob = b'\x02' + comp  # compression byte = zlib
    else:
        blob = sector  # no compression gain, store raw
    sector_offsets.append(cur)
    sector_blobs.append(blob)
    cur += len(blob)
sector_offsets.append(cur)  # end offset

# New block data = offset table + all sectors
offset_table = struct.pack(f'<{num_sectors+1}I', *sector_offsets)
new_block_data = offset_table + b''.join(sector_blobs)
print(f"New block data size: {len(new_block_data)}")

# Now build the new file:
# Layout: [MPQ header + original file data region] [new war3map.j data] [new hash table] [new block table]
mpq_base = 0  # MPQ starts at offset 0 in tmp_mpq
hash_table_abs = header['hash_table_offset']
block_table_abs = header['block_table_offset']

# Read original file data up to hash table
with open(tmp_mpq, 'rb') as f:
    f.seek(0)
    prefix = f.read(hash_table_abs)  # Everything before hash table

# New file layout:
# prefix (header + all old file data) + new_block_data + new_hash_table + new_block_table
new_hash_table_off = header['hash_table_offset'] + len(new_block_data)
new_block_table_off = new_hash_table_off + header['hash_table_entries'] * 16

# Re-encrypt hash table (unchanged, but we need to write it)
hash_key = archive._hash('(hash table)', 'TABLE')
# Re-read raw hash table and re-encrypt it (it's already decrypted in archive.hash_table)
# We need to pack the decrypted entries back and re-encrypt
ht_raw = b''
for entry in archive.hash_table:
    ht_raw += struct.pack('<2I2HI', entry.hash_a, entry.hash_b, entry.locale, entry.platform, entry.block_table_index)
ht_encrypted = archive._decrypt(ht_raw, hash_key)

# Build new block table (decrypted)
bt_raw = b''
for i, entry in enumerate(archive.block_table):
    if i == block_idx:
        # Update to point to new data
        off = header['hash_table_offset']  # New data goes right before hash table
        bt_raw += struct.pack('<4I', off, len(new_block_data), len(new_data), 0x80000200)  # EXISTING | COMPRESS
    else:
        bt_raw += struct.pack('<4I', entry.offset, entry.archived_size, entry.size, entry.flags)
block_key = archive._hash('(block table)', 'TABLE')
bt_encrypted = archive._decrypt(bt_raw, block_key)

# Assemble - write HM3W header + patched MPQ
with open(dst, 'wb') as f:
    f.write(hm3w_header)
    f.write(prefix)
    f.write(new_block_data)
    f.write(ht_encrypted)
    f.write(bt_encrypted)
    
    # Update header (relative to MPQ start, which is now after hm3w_header)
    f.seek(mpq_offset + 8)  # archive_size
    new_archive_size = (block_table_abs + len(bt_encrypted)) - mpq_offset
    f.write(struct.pack('<I', new_archive_size))
    f.seek(mpq_offset + 16)  # hash_table_offset
    f.write(struct.pack('<I', new_hash_table_off))
    f.seek(mpq_offset + 20)  # block_table_offset
    f.write(struct.pack('<I', new_block_table_off))

print(f"\nWritten: {dst} ({os.path.getsize(dst)} bytes)")

# Verify by reopening - extract MPQ part from w3x
with open(dst, 'rb') as f:
    v_w3x = f.read()
v_mpq_off = v_w3x.find(b'MPQ\x1a')
with open(r'D:\dota\DOTA69AI\scripts\temp_verify.mpq', 'wb') as f:
    f.write(v_w3x[v_mpq_off:])
verify = MPQArchive(r'D:\dota\DOTA69AI\scripts\temp_verify.mpq', listfile=False)
v_data = verify.read_file('war3map.j')
print(f"Verification: war3map.j = {len(v_data)} bytes")
if '充值到账'.encode('utf-8') in v_data:
    print("SUCCESS: Recharge code found in packed war3map.j!")
else:
    print("WARNING: Recharge code not found in packed file!")
