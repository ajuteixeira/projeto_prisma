import codecs

file_path = r'c:\Users\bruno\Documents\Projects\html\prisma\profile.html'
with codecs.open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

# Substituir os bytes UTF-8 mal interpretados
content = content.replace(chr(0xF0) + chr(0x9F) + chr(0x8E) + chr(0xAF), chr(0x1F3AF))
content = content.replace(chr(0xF0) + chr(0x9F) + chr(0x91) + chr(0xBB), chr(0x1F47B))
content = content.replace(chr(0xE2) + chr(0x9A) + chr(0xA1), chr(0x26A1))
content = content.replace(chr(0xF0) + chr(0x9F) + chr(0x8F) + chr(0x86), chr(0x1F3C6))
content = content.replace(chr(0xF0) + chr(0x9F) + chr(0x92) + chr(0xA3), chr(0x1F4A3))
content = content.replace(chr(0xF0) + chr(0x9F) + chr(0x94) + chr(0xAB), chr(0x1F52B))
content = content.replace(chr(0xF0) + chr(0x9F) + chr(0x91) + chr(0x91), chr(0x1F451))

with codecs.open(file_path, 'w', encoding='utf-8-sig') as f:
    f.write(content)

print('Encoding corrigido!')
