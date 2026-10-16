"""
MPQ patch v4 - Store war3map.j as UNCOMPRESSED SINGLE_UNIT
This eliminates sector tables and zlib compression as variables.
"""
import sys, os, struct, zlib, shutil
sys.path.insert(0, r'C:\Users\57864\AppData\Local\DoubaoWork\User Data\sandbox_runtime\bases\d0ace100fdff5b2d247847aca1e3d83b\python\Lib\site-packages')
from mpyq import MPQArchive

src = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-latest.w3x'
dst = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'
new_j_path = r'D:\dota\DOTA69AI\src\war3map.j'

# Read HM3W header (first 512 bytes of w3x)
with open(src, 'rb') as f:
    hm3w_header = f.read(512)
    print(f"HM3W header: {len(hm3w_header)} bytes, magic={hm3w_header[:4]}")

# Extract MPQ to temp file
tmp_mpq = r'D:\dota\DOTA69AI\scripts\temp_orig.mpq'
shutil.copy(src, tmp_mpq)
# Strip HM3W header - find MPQ magic
with open(tmp_mpq, 'rb') as f:
    data = f.read()
mpq_pos = data.find(b'MPQ\x1a')
print(f"MPQ magic at offset {mpq_pos}")
with open(tmp_mpq, 'wb') as f:
    f.write(data[mpq_pos:])

archive = MPQArchive(tmp_mpq, listfile=False)
header = archive.header
print(f"Header: hash_off={header['hash_table_offset']}, block_off={header['block_table_offset']}")
print(f"Hash entries: {header['hash_table_entries']}, Block entries: {header['block_table_entries']}")

# Find war3map.j
hash_entry = archive.get_hash_table_entry('war3map.j')
block_idx = hash_entry.block_table_index
orig_block = archive.block_table[block_idx]
print(f"Original war3map.j: block_idx={block_idx}, offset={orig_block.offset}, "
      f"arch={orig_block.archived_size}, uncomp={orig_block.size}, flags=0x{orig_block.flags:08X}")

# Read new war3map.j
with open(new_j_path, 'rb') as f:
    new_data = f.read()
print(f"New war3map.j: {len(new_data)} bytes")

# Strategy: store as SINGLE_UNIT, uncompressed
# Flags: MPQ_FILE_EXISTS | MPQ_FILE_SINGLE_UNIT = 0x81000000
# No sector table, just raw bytes
new_flags = 0x81000000
new_block_data = new_data  # raw, uncompressed

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

# Build new hash table
ht_raw = b''
for entry in archive.hash_table:
    ht_raw += struct.pack('<2I2HI', entry.hash_a, entry.hash_b, entry.locale, entry.platform, entry.block_table_index)
hash_key = archive._hash('(hash table)', 'TABLE')
ht_encrypted = mpq_encrypt(ht_raw, hash_key, archive.encryption_table)

# Build new block table - war3map.j entry points to our new raw data
new_data_pos = header['hash_table_offset']  # Place new data where old HT was
bt_raw = b''
for i, entry in enumerate(archive.block_table):
    if i == block_idx:
        print(f"Updating block {i}: offset -> {new_data_pos}, size -> {len(new_data)}, flags -> 0x{new_flags:08X}")
        bt_raw += struct.pack('<4I', new_data_pos, len(new_block_data), len(new_data), new_flags)
    else:
        bt_raw += struct.pack('<4I', entry.offset, entry.archived_size, entry.size, entry.flags)
block_key = archive._hash('(block table)', 'TABLE')
bt_encrypted = mpq_encrypt(bt_raw, block_key, archive.encryption_table)

# Read prefix (everything up to original hash table)
with open(tmp_mpq, 'rb') as f:
    prefix = f.read(header['hash_table_offset'])

# New MPQ layout: prefix + new_block_data + ht_encrypted + bt_encrypted
new_ht_off = header['hash_table_offset'] + len(new_block_data)
new_bt_off = new_ht_off + header['hash_table_entries'] * 16
new_arch_size = new_bt_off + header['block_table_entries'] * 16

print(f"New HT offset: {new_ht_off}, New BT offset: {new_bt_off}")
print(f"New archive size: {new_arch_size}")

# Assemble new MPQ
new_mpq = bytearray()
new_mpq += prefix
new_mpq += new_block_data
new_mpq += ht_encrypted
new_mpq += bt_encrypted

# Patch MPQ header fields
struct.pack_into('<I', new_mpq, 8, new_arch_size)      # archive_size
struct.pack_into('<I', new_mpq, 16, new_ht_off)        # hash_table_offset
struct.pack_into('<I', new_mpq, 20, new_bt_off)         # block_table_offset

# Write final w3x
with open(dst, 'wb') as f:
    f.write(hm3w_header)
    f.write(new_mpq)

print(f"\nWritten: {dst}")
print(f"Total size: {os.path.getsize(dst)} bytes ({os.path.getsize(dst)/1024/1024:.1f} MB)")

# Verify
verify = MPQArchive(dst, listfile=False)
vdata = verify.read_file('war3map.j')
if vdata:
    print(f"Verification: war3map.j = {len(vdata)} bytes")
    print(f"First 100 chars: {vdata[:100]}")
else:
    print("VERIFICATION FAILED: could not read war3map.j back!")
