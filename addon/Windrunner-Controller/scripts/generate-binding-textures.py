"""Generate the binding editor's original controller diagrams and connector art.

The silhouettes and controls are authored as vector geometry, then rasterized
into antialiased, uncompressed RGBA TGA files for WoW 1.12. Requires Pillow/numpy.
Control centers must match CONTROL_POINTS in config/bindings.lua.
"""

from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont


OUTPUT = Path(__file__).resolve().parents[1] / "textures" / "bindings"
OUTPUT.mkdir(parents=True, exist_ok=True)
SCALE = 3
FONT = "C:/Windows/Fonts/segoeuib.ttf"


def cubic(points):
    a, b, c, d = (np.array(p) for p in points)
    return [tuple((1-t)**3*a + 3*(1-t)**2*t*b + 3*(1-t)*t*t*c + t**3*d)
            for t in np.linspace(0, 1, 32)]


def body_path():
    segments = [
        [(80,105),(60,110),(55,147),(46,180)],
        [(46,180),(36,240),(23,315),(21,356)],
        [(21,356),(17,401),(44,427),(75,416)],
        [(75,416),(105,405),(129,353),(155,316)],
        [(155,316),(169,297),(190,291),(210,294)],
        [(210,294),(238,299),(274,299),(302,294)],
        [(302,294),(322,291),(343,297),(357,316)],
        [(357,316),(381,353),(407,405),(437,416)],
        [(437,416),(468,427),(495,401),(491,356)],
        [(491,356),(489,315),(476,240),(466,180)],
        [(466,180),(457,147),(452,110),(432,105)],
        [(432,105),(380,74),(327,79),(256,87)],
        [(256,87),(185,79),(132,74),(80,105)],
    ]
    return [(round(x*SCALE),round(y*SCALE)) for segment in segments for x,y in cubic(segment)]


def diagram(kind):
    size = 512*SCALE
    mask = Image.new("L", (size,size))
    ImageDraw.Draw(mask).polygon(body_path(), fill=255)
    yy, xx = np.mgrid[:size,:size]
    shine = np.clip(1-yy/size,0,1)*30 + np.exp(-((xx-size/2)/(size/2))**2)*9
    colors = np.stack((54+shine,59+shine,66+shine),axis=2).astype(np.uint8)
    pixels = np.dstack((colors,np.asarray(mask)))
    image = Image.new("RGBA",(size,size))
    shadow = Image.new("RGBA",(size,size),(0,0,0,0))
    shadow.putalpha(mask.filter(ImageFilter.GaussianBlur(5*SCALE)).point(lambda a: round(a*.55)))
    image.alpha_composite(shadow)
    image.alpha_composite(Image.fromarray(pixels))
    draw = ImageDraw.Draw(image)
    draw.line(body_path()+[body_path()[0]],fill=(150,157,164,230),width=2*SCALE)

    def bounds(x,y,w,h):
        return tuple(round(v*SCALE) for v in (x-w/2,y-h/2,x+w/2,y+h/2))

    def ellipse(x,y,w,h,fill,outline=None,width=1):
        draw.ellipse(bounds(x,y,w,h),fill=fill,outline=outline,width=round(width*SCALE))

    def rect(x,y,w,h,radius,fill,outline=None):
        draw.rounded_rectangle(bounds(x,y,w,h),radius=radius*SCALE,fill=fill,outline=outline,width=SCALE)

    # Raised shoulders and trigger caps, shared by both controller families.
    for x in (112,400):
        rect(x,75,60,26,8,(41,47,54,255),(139,147,154,255))
    for x in (117,395):
        rect(x,94,92,25,9,(34,39,44,255),(139,147,154,255))

    # Grip seams follow the shell and remain quiet at the actual UI size.
    for points in ([(55,239),(49,289),(42,355),(63,391)],[(457,239),(463,289),(470,355),(449,391)]):
        draw.line([(x*SCALE,y*SCALE) for x,y in points],fill=(34,39,45,150),width=3*SCALE)

    sticks = [(132,172),(342,268)] if kind=="xbox" else [(176,274),(336,274)]
    for x,y in sticks:
        ellipse(x,y,102,102,(33,38,44,255),(143,151,158,255),2)
        ellipse(x,y,84,84,(55,62,70,255),(15,19,24,255),3)
        ellipse(x,y,64,64,(30,36,42,255),(87,98,108,255),2)
        ellipse(x,y-3,51,48,(51,60,67,255))

    dx,dy = (176,258) if kind=="xbox" else (120,172)
    ellipse(dx,dy,83,83,(39,45,52,255),(123,133,142,255),2)
    cross = [(-12,-35),(12,-35),(12,-12),(35,-12),(35,12),(12,12),(12,35),
             (-12,35),(-12,12),(-35,12),(-35,-12),(-12,-12)]
    draw.polygon([((dx+x)*SCALE,(dy+y)*SCALE) for x,y in cross],fill=(27,31,36,255),outline=(147,153,159,255),width=SCALE)
    ellipse(dx,dy,11,11,(70,78,84,255))

    fx,fy = (388,169) if kind=="xbox" else (392,172)
    buttons = [(fx,fy+31,"A",(106,216,142,255)),(fx-31,fy,"X",(102,171,239,255)),
               (fx,fy-31,"Y",(239,211,107,255)),(fx+31,fy,"B",(237,121,119,255))]
    for x,y,label,color in buttons:
        ellipse(x,y,38,38,(27,32,38,255),(132,142,151,255),1.5)
        if kind=="xbox":
            draw.text((x*SCALE,y*SCALE),label,font=ImageFont.truetype(FONT,20*SCALE),anchor="mm",fill=color)
        else:
            color={"A":(102,171,239,255),"X":(223,135,208,255),"Y":(106,216,167,255),"B":(237,151,119,255)}[label]
            if label=="A":
                draw.line([((x-7)*SCALE,(y-7)*SCALE),((x+7)*SCALE,(y+7)*SCALE)],fill=color,width=2*SCALE)
                draw.line([((x-7)*SCALE,(y+7)*SCALE),((x+7)*SCALE,(y-7)*SCALE)],fill=color,width=2*SCALE)
            elif label=="X": draw.rectangle(bounds(x,y,14,14),outline=color,width=2*SCALE)
            elif label=="Y": draw.polygon([(x*SCALE,(y-8)*SCALE),((x-8)*SCALE,(y+7)*SCALE),((x+8)*SCALE,(y+7)*SCALE)],outline=color,width=2*SCALE)
            else: ellipse(x,y,16,16,None,color,2)

    if kind=="ps":
        rect(256,140,145,75,9,(39,45,52,255),(129,141,152,255))
        rect(167,132,16,24,5,(32,38,44,255),(130,143,153,255))
        rect(345,132,16,24,5,(32,38,44,255),(130,143,153,255))
        ellipse(256,235,25,25,(34,39,44,255),(123,133,143,255))
    else:
        ellipse(256,122,27,27,(35,41,48,255),(143,155,166,255))
        for x in (222,290): ellipse(x,164,20,20,(33,39,45,255),(128,139,149,255))
    draw.text((256*SCALE,210*SCALE),"WINDRUNNER",font=ImageFont.truetype(FONT,11*SCALE),anchor="mm",fill=(159,167,175,180))
    image.resize((512,512),Image.Resampling.LANCZOS).save(OUTPUT/f"{kind}.tga",compression=None)


for kind in ("xbox","ps"):
    diagram(kind)
yy, xx = np.mgrid[:128,:128]
alpha = np.clip(1.2-np.abs(xx-yy)/np.sqrt(2),0,1)*255
alpha *= np.clip(np.minimum(xx,127-xx)/3,0,1)
pixels = np.full((128,128,4),255,np.uint8)
pixels[:,:,3] = alpha.astype(np.uint8)
Image.fromarray(pixels).save(OUTPUT/"diagonal.tga",compression=None)
print(f"Generated Xbox, PlayStation, and connector textures in {OUTPUT}")
