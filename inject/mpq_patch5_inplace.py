"""
MPQ patch v5 - IN-PLACE patch (no layout changes)
Strategy: new compressed data is SMALLER than original, so we can overwrite
the original war3map.j data in place. Only update the block table entry.
Everything else stays byte-for-byte identical to the original.
"""
import sys, os, struct, zlib, shutil
sys.path.insert(0, r'C:\Users\57864\AppData\Local\DoubaoWork\User Data\sandbox_runtime\bases\d0ace100fdff5b2d247847aca1e3d83b\python\Lib\site-packages')
from mpyq import MPQArchive

src = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-latest.w3x'
dst = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'
new_j_path = r'D:\dota\DOTA69AI\src\war3map.j'

# Step 1: Read entire original w3x into memory
with open(src, 'rb') as f:
    raw = bytearray(f.read())
print(f"Original file: {len(raw)} bytes")

# Step 2: Find MPQ offset (after HM3W header)
mpq_rel_offset = raw.find(b'MPQ\x1a')
print(f"MPQ magic at file offset: {mpq_rel_offset}")

# Step 3: Open MPQ (extract to temp for mpyq to parse)
tmp_mpq = r'D:\dota\DOTA69AI\scripts\temp_orig2.mpq'
with open(tmp_mpq, 'wb') as f:
    f.write(raw[mpq_rel_offset:])

archive = MPQArchive(tmp_mpq, listfile=False)
header = archive.header
print(f"Hash table offset (MPQ-relative): {header['hash_table_offset']}")
print(f"Block table offset (MPQ-relative): {header['block_table_offset']}")
print(f"Block entries: {header['block_table_entries']}")

# Step 4: Find war3map.j block entry
hash_entry = archive.get_hash_table_entry('war3map.j')
block_idx = hash_entry.block_table_index
orig_block = archive.block_table[block_idx]
print(f"\nOriginal war3map.j block entry:")
print(f"  offset (MPQ-rel): {orig_block.offset}")
print(f"  archived_size: {orig_block.archived_size}")
print(f"  uncompressed_size: {orig_block.size}")
print(f"  flags: 0x{orig_block.flags:08X}")

# Step 5: Compress new war3map.j data the same way as original
with open(new_j_path, 'rb') as f:
    new_data = f.read()
print(f"\nNew war3map.j: {len(new_data)} bytes (uncompressed)")

sector_size = 512 << header['sector_size_shift']
num_sectors = (len(new_data) + sector_size - 1) // sector_size

sector_offsets = []
sector_blobs = []
offset_table_size = (num_sectors + 1) * 4
cur = offset_table_size
for i in range(num_sectors):
    s = i * sector_size
    e = min(s + sector_size, len(new_data))
    sector = new_data[s:e]
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
new_block_data = offset_table + b''.join(sector_blobs)
print(f"New compressed data: {len(new_block_data)} bytes, sectors: {num_sectors}")
print(f"Original archived size: {orig_block.archived_size}")
print(f"New size fits in original? {len(new_block_data) <= orig_block.archived_size}")

assert len(new_block_data) <= orig_block.archived_size, \
    f"New data ({len(new_block_data)}) is bigger than original ({orig_block.archived_size})!"

# Step 6: Write new compressed data at the original war3map.j offset
# Both offsets are relative to MPQ start, so add mpq_rel_offset
data_abs_offset = mpq_rel_offset + orig_block.offset
print(f"\nWriting new data at file offset: {data_abs_offset}")

# Write new data
raw[data_abs_offset:data_abs_offset + len(new_block_data)] = new_block_data
# Zero-pad the rest of the original block area
pad_size = orig_block.archived_size - len(new_block_data)
if pad_size > 0:
    pad_start = data_abs_offset + len(new_block_data)
    raw[pad_start:pad_start + pad_size] = b'\x00' * pad_size
    print(f"Padded {pad_size} bytes with zeros")

# Step 7: Update block table entry
# Block table is encrypted. We need to:
# a) Read encrypted block table from raw file
# b) Decrypt it
# c) Modify the war3map.j entry
# d) Re-encrypt it
# e) Write it back

block_table_abs_offset = mpq_rel_offset + header['block_table_offset']
block_table_size = header['block_table_entries'] * 16
print(f"\nBlock table at file offset: {block_table_abs_offset}, size: {block_table_size}")

# Read encrypted block table
enc_bt = bytes(raw[block_table_abs_offset:block_table_abs_offset + block_table_size])

# Decrypt it using mpyq's internal method
block_key = archive._hash('(block table)', 'TABLE')
dec_bt = bytearray(archive._decrypt(enc_bt, block_key))

# Verify decrypted block table matches what mpyq parsed
# (just for sanity, first entry should match)
test_offset, test_arch, test_size, test_flags = struct.unpack_from('<4I', dec_bt, 0)
print(f"First block entry (decrypted): offset={test_offset}, arch={test_arch}, size={test_size}, flags=0x{test_flags:08X}")

# Modify the war3map.j entry
entry_offset = block_idx * 16
print(f"Modifying block entry {block_idx} at byte offset {entry_offset} within block table")

# New values: same offset, new archived_size, new uncompressed_size, same flags
struct.pack_into('<4I', dec_bt, entry_offset,
                 orig_block.offset,      # offset stays the same
                 len(new_block_data),   # new archived_size
                 len(new_data),          # new uncompressed_size
                 orig_block.flags)      # flags stay the same

# Re-encrypt
def mpq_encrypt(data, key, enc_table):
    seed1 = key
    seed2 = 0xEEEEEEEE
    result = bytearray()
    for i in range(len(data) // 4):
        seed2 = (seed2 + enc_table[0x400 + (seed1 & 0xFF)]) & 0xFFFFFFFF
        plaintext = struct.unpack_from("<I", data, i*4)[0]
        ciphertext = (plaintext ^ ((seed1 + seed2) & 0xFFFFFFFF)) & 0xFFFFFFFF
        seed1 = (((~seed1 << 0x15) + 0x11111111) | (seed1 >> 0x0B)) & 0xFFFFFFFF
        seed2 = (plaintext + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
        result += struct.pack("<I", ciphertext)
    return bytes(result)

new_enc_bt = mpq_encrypt(dec_bt, block_key, archive.encryption_table)

# Write back to raw
raw[block_table_abs_offset:block_table_abs_offset + block_table_size] = new_enc_bt

# Step 8: Write output
with open(dst, 'wb') as f:
    f.write(raw)

print(f"\nWritten: {dst}")
print(f"Total size: {os.path.getsize(dst)} bytes ({os.path.getsize(dst)/1024/1024:.1f} MB)")

# Step 9: Verify by reading back
print("\n--- Verification ---")
verify_mpq = r'D:\dota\DOTA69AI\scripts\temp_verify_v5.mpq'
with open(dst, 'rb') as f:
    vraw = f.read()
vmpq_off = vraw.find(b'MPQ\x1a')
with open(verify_mpq, 'wb') as f:
    f.write(vraw[vmpq_off:])

va = MPQArchive(verify_mpq, listfile=False)
vh = va.get_hash_table_entry('war3map.j')
vb = va.block_table[vh.block_table_index]
print(f"war3map.j: offset={vb.offset}, arch={vb.archived_size}, uncomp={vb.size}, flags=0x{vb.flags:08X}")

vdata = va.read_file('war3map.j')
if vdata:
    print(f"Read back OK: {len(vdata)} bytes")
    print(f"First 80 chars: {vdata[:80]}")
else:
    print("FAILED to read war3map.j!")

# Verify other files still work
vlist = va.read_file('(listfile)')
if vlist:
    print(f"(listfile): {len(vlist)} bytes, readable")
