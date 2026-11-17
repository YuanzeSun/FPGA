"""Create a small local bitmap glyph ROM and editable letter header. No installs."""
from pathlib import Path
import hashlib,json,os
from PIL import Image,ImageDraw,ImageFont

root=Path(__file__).resolve().parents[1]
font_dir=Path('C:/Windows/Fonts') if os.name=='nt' else Path('/mnt/c/Windows/Fonts')
body=(root/'assets/letter.txt').read_text(encoding='utf-8-sig').replace('\r','')
messages={'intro':'有些话，想说给你听','prompt':'按 F 或 J，拆开这封信','end':'慢慢来，也没关系。'}
assert max(map(len,body.splitlines()))<=30,'Letter lines must be <=30 characters'
assert len(body.splitlines())<=14,'Letter must fit the page (14 lines)'
chinese=sorted({ch for ch in body+''.join(messages.values()) if ord(ch)>126})
assert len(chinese)<=128,'Too many unique Chinese characters for 256 glyph ROM'
mapping={chr(i):i for i in range(32,127)}|{ch:128+i for i,ch in enumerate(chinese)}
ascii_font=ImageFont.truetype(str(font_dir/'consola.ttf'),18)
zh_font=ImageFont.truetype(str(font_dir/'simhei.ttf'),16)
rows=[[0]*16 for _ in range(256)]
for ch,code in mapping.items():
    im=Image.new('1',(16,16));d=ImageDraw.Draw(im);f=ascii_font if ord(ch)<128 else zh_font
    box=d.textbbox((0,0),ch,font=f);w,h=box[2]-box[0],box[3]-box[1]
    d.text(((16-w)//2-box[0],(16-h)//2-box[1]),ch,font=f,fill=1)
    rows[code]=[sum((1<<(15-x)) for x in range(16) if im.getpixel((x,y))) for y in range(16)]
for y in range(16):
    rows[1][y]=0xffff
    rows[2][y]=0x7ffe if 1<=y<15 else 0
    rows[3][y]=0x7ffe if 1<=y<15 else 0
    if 4<=y<7:rows[3][y]&=~0x318c
    rows[4][y]=0x7ffe if y in [1,14] else 0x4002 if 1<y<14 else 0
heart=['0000000000000000','0001110000111000','0011111001111100','0111111111111110','0111111111111110','0111111111111110','0011111111111100','0001111111111000','0000111111110000','0000011111100000','0000001111000000','0000000110000000','0000000000000000','0000000000000000','0000000000000000','0000000000000000']
rows[5]=[int(r,2) for r in heart]
(root/'assets/font.hex').write_text(''.join(f'{n:04x}\n' for glyph in rows for n in glyph))
def encode(s):return [10 if c=='\n' else mapping[c] for c in s]
header='#ifndef LETTER_TEXT_H\n#define LETTER_TEXT_H\n'
for name,s in {'body':body,**messages}.items():
    values=encode(s)
    header+=f'static const unsigned char letter_{name}[]={{'+','.join(map(str,values))+',0};\n'
header+=f'#define LETTER_LENGTH {len(body)}u\n#endif\n'
(root/'firmware/letter_text.h').write_text(header)
(root/'assets/letter_length.vh').write_text(f'`define LETTER_LENGTH {len(body)}\n')
(root/'assets/glyph-map.json').write_text(json.dumps(mapping,ensure_ascii=False,indent=2),encoding='utf-8')
# Normalize 4x4 rotations to their top/left occupied edge for predictable walls.
shape_rows=[]
for initial in [0x000f,0x0033,0x0072,0x0036,0x0063,0x0071,0x0074]:
    cells={(i%4,i//4) for i in range(16) if initial&(1<<i)};rotations=[]
    for _ in range(4):
        mx=min(x for x,y in cells);my=min(y for x,y in cells)
        cells={(x-mx,y-my) for x,y in cells}
        rotations.append(sum(1<<(y*4+x) for x,y in cells))
        cells={(3-y,x) for x,y in cells}
    shape_rows.append('{'+','.join(f'0x{v:04x}' for v in rotations)+'}')
(root/'firmware/tetrominoes.h').write_text('static const uint16_t shapes[7][4]={'+','.join(shape_rows)+'};\n')
(root/'assets/asset-info.json').write_text(json.dumps({'glyph_count':256,'unique_chinese_characters':len(chinese),'font_rom_bytes':8192,'letter_characters':len(body),'letter_status':'Editable example draft; previous requested wording was not available.','font_sources':[str(font_dir/'consola.ttf'),str(font_dir/'simhei.ttf')],'font_hex_sha256':hashlib.sha256((root/'assets/font.hex').read_bytes()).hexdigest()},ensure_ascii=False,indent=2),encoding='utf-8')
print(json.dumps({'assets':'PASS','chinese_glyphs':len(chinese),'letter_characters':len(body)}))
