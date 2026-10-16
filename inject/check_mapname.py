import sys, os, struct, zlib
sys.path.insert(0, r'C:\Users\57864\AppData\Local\DoubaoWork\User Data\sandbox_runtime\bases\d0ace100fdff5b2d247847aca1e3d83b\python\Lib\site-packages')
from mpyq import MPQArchive

src = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-mod.w3x'
tmp_mpq = r'D:\dota\DOTA69AI\scripts\temp_check.w3x'

with open(src, 'rb') as f:
    raw = f.read()
mpq_off = raw.find(b'MPQ\x1a')
with open(tmp_mpq, 'wb') as f:
    f.write(raw[mpq_off:])

a = MPQArchive(tmp_mpq, listfile=False)

# Check what files relate to map name
for fname in ['war3map.wts', 'war3map.w3i', 'war3map.wpm']:
    h = a.get_hash_table_entry(fname)
    if h:
        data = a.read_file(fname)
        print(f'{fname}: {len(data)} bytes')
        if fname == 'war3map.w3i':
            # w3i format: first 4 bytes = version, then map name is at some offset
            # Let's dump first 200 bytes as text
            try:
                text = data[:200].decode('utf-8', errors='replace')
                print(f'  first 200 bytes text: {repr(text)}')
            except:
                print(f'  hex: {data[:50].hex()}')
        if fname == 'war3map.wts':
            text = data.decode('utf-8', errors='replace')
            lines = text.splitlines()
            for line in lines[:30]:
                if 'MapName' in line or 'mapName' in line or 'Title' in line:
                    print(f'  {line}')
    else:
        print(f'{fname}: not found')
