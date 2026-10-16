import ctypes, os, sys

storm = ctypes.WinDLL(r'D:\dota\DOTA69AI\tool\任何平台单机建图\bin\StormLib.dll')

# SFileOpenArchive
SFileOpenArchive = storm.SFileOpenArchive
SFileOpenArchive.restype = ctypes.c_bool
SFileOpenArchive.argtypes = [ctypes.c_wchar_p, ctypes.c_uint, ctypes.c_uint, ctypes.POINTER(ctypes.c_void_p)]

# SFileAddFile
SFileAddFile = storm.SFileAddFile
SFileAddFile.restype = ctypes.c_bool
SFileAddFile.argtypes = [ctypes.c_void_p, ctypes.c_wchar_p, ctypes.c_wchar_p, ctypes.c_uint, ctypes.c_uint]

# SFileCloseArchive
SFileCloseArchive = storm.SFileCloseArchive
SFileCloseArchive.restype = ctypes.c_bool
SFileCloseArchive.argtypes = [ctypes.c_void_p]

w3x_path = r'D:\dota\DOTA69AI\output\Dota69-OMGAI-latest.w3x'
j_path = r'D:\dota\DOTA69AI\src\war3map.j'

# Open MPQ (0 = read/write, MPQ_OPEN_WRITE=0x02?)
hMpq = ctypes.c_void_p()
# STREAM_FLAG_READ_WRITE = 0x00000020
if not SFileOpenArchive(w3x_path, 0, 0x00000020, ctypes.byref(hMpq)):
    print(f"Failed to open MPQ: {ctypes.GetLastError()}")
    sys.exit(1)
print(f"MPQ opened: {w3x_path}")

# Add/replace war3map.j
# MPQ_FILE_IMPLODE = 0x00000100, MPQ_FILE_COMPRESS = 0x00000200, MPQ_FILE_ENCRYPTED = 0x00010000
# Use compression: MPQ_FILE_COMPRESS | MPQ_FILE_REPLACEEXISTING = 0x80000000
flags = 0x00000200 | 0x80000000  # COMPRESS | REPLACE_EXISTING
if not SFileAddFile(hMpq, j_path, r'war3map.j', 0, flags):
    err = ctypes.GetLastError()
    print(f"Failed to add file: {err}")
    # Try without replace flag
    if not SFileAddFile(hMpq, j_path, r'war3map.j', 0, 0x00000200):
        print(f"Also failed without replace: {ctypes.GetLastError()}")
        SFileCloseArchive(hMpq)
        sys.exit(1)

print("war3map.j added/replaced successfully")
SFileCloseArchive(hMpq)
print("Done!")
