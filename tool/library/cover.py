from PIL import Image, ImageDraw, ImageFilter, ImageEnhance
import random, math
random.seed(7)
W,H=1000,1700
wood=Image.open('wood8.png').convert('RGB')
# rotate texture so planks run vertical-ish? keep horizontal; crop & scale
wood=wood.resize((2200,2200),Image.LANCZOS).crop((300,200,300+W,200+H))
wood=ImageEnhance.Brightness(wood).enhance(0.95)
canvas=wood.convert('RGBA')
# dish: (id, cx, cy, r) crop in source rel units (cx,cy fraction of w,h; r fraction of min(w,h)); placement (x,y,diameter, plate style)
dishes=[
 ('lib-wb-pancakes-north-american',.5,.47,.30,  (210,200,360,'plate')),
 ('lib-wb-cioppino-italian-seafood-stew',.5,.5,.40, (700,180,400,'bowl')),
 ('lib-wb-guacamole-i',.47,.47,.27,  (470,470,250,'bowl')),
 ('lib-wb-english-breakfast',.5,.5,.46,  (190,640,400,'plate')),
 ('lib-wb-gyudon-japanese-beef-and-rice-bowl',.5,.45,.40,  (790,600,360,'bowl')),
 ('lib-wb-meat-and-shrimp-potstickers',.45,.45,.34,  (500,850,370,'plate')),
 ('lib-wb-matar-paneer',.40,.5,.32,  (170,1080,340,'plate')),
 ('lib-wb-miso-soup',.5,.48,.33,  (860,960,260,'bowl')),
 ('lib-wb-chow-mein',.5,.5,.45,  (700,1250,400,'plate')),
 ('lib-wb-pecan-pie',.52,.55,.30,  (310,1420,340,'plate')),
 ('lib-wb-coleslaw-i',.5,.5,.42,  (60,1560,260,'bowl')),
 ('lib-wb-corn-chowder-i',.55,.5,.30,  (930,1600,300,'bowl')),
 ('lib-wb-chicken-vindaloo',.5,.5,.38,  (470,1120,220,'bowl')),
]
def disc(img,cx,cy,r,d):
    w,h=img.size; R=r*min(w,h); x0=cx*w-R; y0=cy*h-R
    c=img.crop((int(x0),int(y0),int(x0+2*R),int(y0+2*R))).resize((d,d),Image.LANCZOS).convert('RGBA')
    m=Image.new('L',(d,d),0); ImageDraw.Draw(m).ellipse([0,0,d-1,d-1],fill=255)
    c.putalpha(m); return c
for did,cx,cy,r,(x,y,D,style) in dishes:
    src=Image.open(f'photos/{did}.jpg').convert('RGB')
    src=ImageEnhance.Color(src).enhance(1.15)
    # shadow
    sh=Image.new('RGBA',canvas.size,(0,0,0,0)); sd=ImageDraw.Draw(sh)
    sd.ellipse([x-D/2+14,y-D/2+22,x+D/2+14,y+D/2+22],fill=(20,8,0,150))
    sh=sh.filter(ImageFilter.GaussianBlur(18)); canvas=Image.alpha_composite(canvas,sh)
    plate=Image.new('RGBA',(D,D),(0,0,0,0)); pd=ImageDraw.Draw(plate)
    base=(246,244,238) if style=='plate' else (238,232,222)
    pd.ellipse([0,0,D-1,D-1],fill=base+(255,))
    # rim shading
    for i in range(10):
        pd.ellipse([i,i,D-1-i,D-1-i],outline=(225-i*2,222-i*2,215-i*2,255))
    inner=int(D*(0.80 if style=='plate' else 0.86))
    pd.ellipse([(D-inner)//2-3,(D-inner)//2-3,(D+inner)//2+3,(D+inner)//2+3],fill=(215,210,200,255))
    food=disc(src,cx,cy,r,inner)
    plate.alpha_composite(food,((D-inner)//2,(D-inner)//2))
    # highlight
    hl=Image.new('RGBA',(D,D),(0,0,0,0)); ImageDraw.Draw(hl).ellipse([D*0.12,D*0.06,D*0.55,D*0.3],fill=(255,255,255,45))
    hl=hl.filter(ImageFilter.GaussianBlur(D*0.05)); plate=Image.alpha_composite(plate,hl)
    canvas.alpha_composite(plate,(int(x-D/2),int(y-D/2)))
# vignette
v=Image.new('L',canvas.size,0); ImageDraw.Draw(v).ellipse([-250,-250,W+250,H+250],fill=255); v=v.filter(ImageFilter.GaussianBlur(220))
dark=Image.new('RGBA',canvas.size,(25,10,0,255)); canvas=Image.composite(canvas,dark,v)
canvas.convert('RGB').save('/home/claude/recipe_box/assets/images/cover.jpg',quality=82,optimize=True)
canvas.convert('RGB').resize((500,850)).save('cover_prev.jpg')
