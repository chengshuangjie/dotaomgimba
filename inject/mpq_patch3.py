"""Patch war3map.j inside a .w3x MPQ - debug version."""
import struct, zlib, os, sys
from io import BytesIO

sys.path.insert(0, r'C:\Users\57864\AppData\Local\DoubaoWork\User Data\sandbox_runtime\bases\d0ace100fdff5b2d247847aca1e3d83b\python\Lib\site-packages')
from mpyq import MPQArchive

src = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-latest.w3x'
dst = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'
new_j = r'D:\dota\DOTA69AI\src\war3map.j'

# Read w3x, extract MPQ
with open(src, 'rb') as f:
    w3x_data = f.read()
mpq_offset = w3x_data.find(b'MPQ\x1a')
hm3w_header = w3x_data[:mpq_offset]
mpq_data = w3x_data[mpq_offset:]

tmp_mpq = r'D:\dota\DOTA69AI\scripts\temp_src.mpq'
with open(tmp_mpq, 'wb') as f:
    f.write(mpq_data)

archive = MPQArchive(tmp_mpq, listfile=False)
header = archive.header
print(f"MPQ offset in w3x: {mpq_offset}")
print(f"Hash table offset: {header['hash_table_offset']}, entries: {header['hash_table_entries']}")
print(f"Block table offset: {header['block_table_offset']}, entries: {header['block_table_entries']}")

hash_entry = archive.get_hash_table_entry('war3map.j')
block_idx = hash_entry.block_table_index
print(f"war3map.j block index: {block_idx}")
block_entry = archive.block_table[block_idx]
print(f"Old block: offset={block_entry.offset}, arch={block_entry.archived_size}, uncomp={block_entry.size}, flags=0x{block_entry.flags:08X}")

# Read new file
with open(new_j, 'rb') as f:
    new_data = f.read()
print(f"New war3map.j: {len(new_data)} bytes")

# Build compressed sectors
sector_size = 512 << header['sector_size_shift']
num_sectors = (len(new_data) + sector_size - 1) // sector_size

sector_offsets = []
sector_blobs = []
offset_table_size = (num_sectors + 1) * 4
cur = offset_table_size  # First sector starts after offset table
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
print(f"New block data: {len(new_block_data)} bytes, sectors: {num_sectors}")

def mpq_encrypt(data, key, enc_table):
    """MPQ encryption (opposite of mpyq's _decrypt)."""
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

# Build new hash table (re-encrypt with correct function)
ht_raw = b''
for entry in archive.hash_table:
    ht_raw += struct.pack('<2I2HI', entry.hash_a, entry.hash_b, entry.locale, entry.platform, entry.block_table_index)
hash_key = archive._hash('(hash table)', 'TABLE')
ht_encrypted = mpq_encrypt(ht_raw, hash_key, archive.encryption_table)

# Build new block table (re-encrypted, with war3map.j updated)
new_data_pos = header['hash_table_offset']  # New data goes right before hash table
bt_raw = b''
for i, entry in enumerate(archive.block_table):
    if i == block_idx:
        print(f"Updating block {i}: offset {entry.offset} -> {new_data_pos}, arch {entry.archived_size} -> {len(new_block_data)}, flags 0x{entry.flags:08X} -> 0x80000200")
        bt_raw += struct.pack('<4I', new_data_pos, len(new_block_data), len(new_data), 0x80000200)
    else:
        bt_raw += struct.pack('<4I', entry.offset, entry.archived_size, entry.size, entry.flags)
block_key = archive._hash('(block table)', 'TABLE')
bt_encrypted = mpq_encrypt(bt_raw, block_key, archive.encryption_table)

# Read prefix (everything up to hash table in original MPQ)
with open(tmp_mpq, 'rb') as f:
    prefix = f.read(header['hash_table_offset'])

# New MPQ layout: prefix + new_block_data + ht_encrypted + bt_encrypted
new_ht_off = header['hash_table_offset'] + len(new_block_data)
new_bt_off = new_ht_off + header['hash_table_entries'] * 16
new_arch_size = new_bt_off + header['block_table_entries'] * 16

print(f"New HT offset: {new_ht_off}, New BT offset: {new_bt_off}")
print(f"New archive size: {new_arch_size}")

# Assemble MPQ
new_mpq = bytearray()
new_mpq += prefix
new_mpq += new_block_data
new_mpq += ht_encrypted
new_mpq += bt_encrypted

# Patch header fields
struct.pack_into('<I', new_mpq, 8, new_arch_size)  # archive_size at offset 8
struct.pack_into('<I', new_mpq, 16, new_ht_off)   # hash_table_offset at offset 16
struct.pack_into('<I', new_mpq, 20, new_bt_off)   # block_table_offset at offset 20

# Write w3x = HM3W header + new MPQ
with open(dst, 'wb') as f:
    f.write(hm3w_header)
    f.write(new_mpq)

print(f"\nWritten: {dst} ({os.path.getsize(dst)} bytes)")

# Verify
with open(dst, 'rb') as f:
    v = f.read()
v_off = v.find(b'MPQ\x1a')
with open(r'D:\dota\DOTA69AI\scripts\temp_verify.mpq', 'wb') as f:
    f.write(v[v_off:])
verify = MPQArchive(r'D:\dota\DOTA69AI\scripts\temp_verify.mpq', listfile=False)
he = verify.get_hash_table_entry('war3map.j')
if he:
    be = verify.block_table[he.block_table_index]
    print(f"Verify block: offset={be.offset}, arch={be.archived_size}, uncomp={be.size}, flags=0x{be.flags:08X}")
    v_data = verify.read_file('war3map.j')
    if v_data:
        print(f"war3map.j size: {len(v_data)}")
        if '充值到账'.encode('utf-8') in v_data:
            print("SUCCESS!")
        else:
            print("WARNING: recharge text not found")
    else:
        print("read_file returned None")
else:
    print("war3map.j not found in hash table!")
