"""Minimal MPQ patcher: replace war3map.j in a .w3x file."""
import struct, os, sys, zlib, hashlib

# MPQ hash types
MPQ_HASH_OFFSET_KEY = 0x00000000
MPQ_HASH_OFFSET_A = 0x00000001
MPQ_HASH_OFFSET_B = 0x00000002

# Block flags
MPQ_FILE_IMPLODE = 0x00000100
MPQ_FILE_COMPRESS = 0x00000200
MPQ_FILE_ENCRYPTED = 0x00010000
MPQ_FILE_KEY_FIX = 0x00020000
MPQ_FILE_PATCH_FILE = 0x00100000
MPQ_FILE_SINGLE_UNIT = 0x01000000
MPQ_FILE_DELETE_MARKER = 0x02000000
MPQ_FILE_SECTOR_CRC = 0x04000000
MPQ_FILE_EXISTS = 0x80000000

def hash_string(s, hash_type):
    """MPQ hash algorithm."""
    if isinstance(s, str):
        s = s.encode('ascii', errors='ignore').upper()
    seed1 = 0x7FED7FED
    seed2 = 0xEEEEEEEE
    for ch in s:
        c = ord(ch) if isinstance(ch, str) else ch
        seed1 = (crypt_table[hash_type][c] ^ ((seed1 + seed2) & 0xFFFFFFFF)) & 0xFFFFFFFF
        seed2 = (c + seed1 + seed2 + (seed2 << 5) + 3) & 0xFFFFFFFF
    return seed1

# Build crypt table
crypt_table = [[0]*256 for _ in range(5)]
def build_crypt_table():
    seed = 0x00100001
    for i in range(256):
        for j in range(5):
            seed = (seed * 125 + 3) % 0x2AAAAB
            temp1 = (seed & 0xFFFF) << 0x10
            seed = (seed * 125 + 3) % 0x2AAAAB
            temp2 = (seed & 0xFFFF)
            crypt_table[j][i] = (temp1 | temp2) & 0xFFFFFFFF
build_crypt_table()

# Simple hash table lookups
HASH_TABLE_SIZE = 16  # Will be read from file

def find_mpq(data):
    """Find MPQ header offset in .w3x (skip HM3W header)."""
    idx = data.find(b'MPQ\x1a')
    return idx

def patch_w3x(w3x_path, new_j_path, output_path):
    with open(w3x_path, 'rb') as f:
        data = bytearray(f.read())

    mpq_off = find_mpq(bytes(data))
    print(f"MPQ at offset {mpq_off}")

    # Parse MPQ header (32 bytes for v1)
    # 0x04: header_size, 0x08: archive_size, 0x0C: format_ver(H), 0x0E: block_size(H)
    # 0x10: hash_table_off, 0x14: block_table_off, 0x18: hash_entries, 0x1C: block_entries
    header_size, archive_size = struct.unpack_from('<II', data, mpq_off+4)
    format_version, block_size = struct.unpack_from('<HH', data, mpq_off+12)
    hash_table_off, block_table_off = struct.unpack_from('<II', data, mpq_off+16)
    hash_table_size = struct.unpack_from('<I', data, mpq_off+24)[0]
    block_table_size = struct.unpack_from('<I', data, mpq_off+28)[0]

    print(f"Header size: {header_size}, archive size: {archive_size}")
    print(f"Format version: {format_version}, block size: {block_size}")
    print(f"Hash table: off={hash_table_off}, size={hash_table_size}")
    print(f"Block table: off={block_table_off}, size={block_table_size}")

    # Read hash table
    htable_abs = mpq_off + hash_table_off
    btable_abs = mpq_off + block_table_off

    # Find war3map.j in hash table
    name_a = hash_string('war3map.j', MPQ_HASH_OFFSET_A)
    name_b = hash_string('war3map.j', MPQ_HASH_OFFSET_B)
    name_key = hash_string('war3map.j', MPQ_HASH_OFFSET_KEY)

    found_block = -1
    for i in range(hash_table_size):
        entry_off = htable_abs + i * 16
        a, b, locale, block_index = struct.unpack_from('<IIII', data, entry_off)
        if a == name_a and b == name_b:
            found_block = block_index
            print(f"Found war3map.j at hash entry {i}, block index {block_index}")
            break

    if found_block < 0:
        print("war3map.j not found!")
        sys.exit(1)

    # Read new file data
    with open(new_j_path, 'rb') as f:
        new_file_data = f.read()
    print(f"New war3map.j size: {len(new_file_data)}")

    # Compress new file (zlib)
    compressed = zlib.compress(new_file_data, 9)
    print(f"Compressed size: {len(compressed)}")

    sector_size = 512 << block_size
    num_sectors = (len(new_file_data) + sector_size - 1) // sector_size

    # Build sector table
    # For compressed files: each sector is compressed independently
    # Sector table: num_sectors + 1 offsets (relative to start of sector data)
    # Then sector CRCs (if flag set)
    sector_offsets = []
    offset = 0
    sector_data_parts = []
    for i in range(num_sectors):
        start = i * sector_size
        end = min(start + sector_size, len(new_file_data))
        sector = new_file_data[start:end]
        comp = zlib.compress(sector, 9)
        if len(comp) < len(sector):
            sector_data_parts.append(comp)
        else:
            sector_data_parts.append(sector)
        sector_offsets.append(offset)
        offset += len(sector_data_parts[-1])
    sector_offsets.append(offset)  # End offset

    # Build the file data: sector offset table + sector data
    sector_table = struct.pack(f'<{num_sectors+1}I', *sector_offsets)
    new_block_data = sector_table + b''.join(sector_data_parts)

    # Truncate the file at MPQ end (remove old block table and anything after)
    # New layout: [MPQ header + existing files] + [new file data] + [new hash table] + [new block table]
    # We need to rebuild from block_table_off

    # New file data goes right after the archive (before hash/block tables)
    # Actually, we need to insert new data between existing file data and hash table

    # Current: [header...hash_table...block_table]
    # New: [header...file_data...NEW_DATA...hash_table...block_table]
    # But we can't easily insert. Instead, append at end and update offsets.

    # Simpler approach: rebuild the MPQ from scratch
    # Keep all existing files' data, but replace war3map.j

    # Read old block table entry for war3map.j
    old_block_off = btable_abs + found_block * 16
    old_file_pos, old_comp_size, old_uncomp_size, old_flags = struct.unpack_from('<IIII', data, old_block_off)
    print(f"Old block: pos={old_file_pos}, comp={old_comp_size}, uncomp={old_uncomp_size}, flags=0x{old_flags:08X}")

    # We'll build new file: [header up to hash_table_off] + [all old file data except war3map.j] + [new war3map.j data] + [new hash table] + [new block table]
    # This is complex. Let's use a simpler approach: append new data at end, update block table entry.

    # New approach:
    # 1. Keep everything up to block_table_off
    # 2. Append new war3map.j data
    # 3. Write new hash table (same as old, but hash table is encrypted...)
    # Actually hash tables are not encrypted in MPQ1.

    # Wait - hash and block tables are stored AFTER file data.
    # Current layout: [header][file data region][hash_table][block_table]
    # We want: [header][file data region (unchanged except old war3map.j)][new war3map.j][new hash_table][new block_table]

    # Since we can't easily remove old war3map.j data from the middle, we'll:
    # 1. Keep old data (old war3map.j becomes orphaned, takes up space but unused)
    # 2. Append new war3map.j at the end (right before hash table)
    # 3. Update block table entry to point to new data
    # 4. Write new hash and block tables at the very end

    # New layout:
    # [existing data up to block_table_off] [new war3map.j data] [new hash table] [new block table]

    new_data_start = mpq_off + hash_table_off  # This is where hash table starts currently
    # We'll insert new file data right before hash table

    # Build output: everything up to hash_table_off + new file data + new hash table + new block table
    out = bytearray()
    out += data[:htable_abs]  # Everything up to hash table (includes header and all file data)

    # Append new war3map.j data
    new_file_abs_pos = hash_table_off  # Relative to MPQ start
    out += new_block_data

    # Build new hash table (copy old, no changes needed except it's the same entries)
    # Hash table entries: name1, name2, locale, blockIndex (16 bytes each)
    htable_data = bytes(data[htable_abs:htable_abs + hash_table_size * 16])

    # Build new block table
    btable_data = bytearray()
    for i in range(block_table_size):
        boff = btable_abs + i * 16
        file_pos, comp_size, uncomp_size, flags = struct.unpack_from('<IIII', data, boff)
        if i == found_block:
            # Update to point to new data
            file_pos = new_file_abs_pos
            comp_size = len(new_block_data)
            uncomp_size = len(new_file_data)
            flags = MPQ_FILE_COMPRESS | MPQ_FILE_EXISTS
        btable_data += struct.pack('<IIII', file_pos, comp_size, uncomp_size, flags)

    # Append hash table and block table
    out += htable_data
    out += bytes(btable_data)

    # Update MPQ header
    new_archive_size = len(out) - mpq_off
    struct.pack_into('<I', out, mpq_off + 8, new_archive_size)
    # Update block_table_off = hash_table_off + hash_table_size * 16
    new_btable_off = hash_table_off + len(new_block_data) + hash_table_size * 16
    struct.pack_into('<I', out, mpq_off + 16, new_btable_off)

    with open(output_path, 'wb') as f:
        f.write(out)
    print(f"Written: {output_path} ({len(out)} bytes)")

if __name__ == '__main__':
    patch_w3x(
        r'D:\dota\DOTA69AI\output\Dota69-OMGAI-latest.w3x',
        r'D:\dota\DOTA69AI\src\war3map.j',
        r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'
    )
