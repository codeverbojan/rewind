"""Compile pinned Lucide SVG geometry into native Core Graphics instructions.
No SVG library/runtime is shipped. The generated paths remain vector at any size.
"""
import math
import re
import xml.etree.ElementTree as ET
from pathlib import Path
ROOT = Path(__file__).resolve().parent

def pt(x,y): return 'CGPointMake(%.6g, %.6g)' % (x,y)
def path_code(data):
    tokens = re.findall(r'[a-zA-Z]|[-+]?(?:\d*\.\d+|\d+\.?\d*)(?:[eE][-+]?\d+)?', data)
    output=[]; x=y=sx=sy=0.; i=0; cmd=None
    def line(nx,ny): output.append('CGContextAddLineToPoint(c, %.6g, %.6g);' % (nx,ny))
    while i<len(tokens):
        if tokens[i].isalpha(): cmd=tokens[i];i+=1
        op=cmd.upper(); relative=cmd.islower()
        if op=='Z': output.append('CGContextClosePath(c);'); x,y=sx,sy;cmd=None;continue
        n={'M':2,'L':2,'H':1,'V':1,'C':6,'Q':4,'A':7}[op]
        v=list(map(float,tokens[i:i+n])); i+=n
        if op in ('M','L'):
            nx,ny=v; nx+=x if relative else 0;ny+=y if relative else 0
            output.append(('CGContextMoveToPoint' if op=='M' else 'CGContextAddLineToPoint')+'(c, %.6g, %.6g);'%(nx,ny))
            x,y=nx,ny
            if op=='M': sx,sy=x,y;cmd='l' if relative else 'L'
        elif op=='H': x=v[0]+(x if relative else 0);line(x,y)
        elif op=='V': y=v[0]+(y if relative else 0);line(x,y)
        elif op in ('C','Q'):
            coords=[v[k]+((x if k%2==0 else y) if relative else 0) for k in range(n)]
            output.append(('CGContextAddCurveToPoint' if op=='C' else 'CGContextAddQuadCurveToPoint')+'(c, '+', '.join('%.6g'%z for z in coords)+');');x,y=coords[-2:]
        elif op=='A':
            rx,ry,angle,large,sweep,nx,ny=v;rx,ry=abs(rx),abs(ry);nx+=x if relative else 0;ny+=y if relative else 0
            if rx==0 or ry==0: line(nx,ny);x,y=nx,ny;continue
            phi=math.radians(angle); co,si=math.cos(phi),math.sin(phi)
            xp=co*(x-nx)/2+si*(y-ny)/2;yp=-si*(x-nx)/2+co*(y-ny)/2
            scale=max(1,math.sqrt(xp*xp/(rx*rx)+yp*yp/(ry*ry)));rx*=scale;ry*=scale
            den=rx*rx*yp*yp+ry*ry*xp*xp
            f=((-1 if bool(large)==bool(sweep) else 1)*math.sqrt(max(0,(rx*rx*ry*ry-den)/den))) if den else 0
            cxp=f*rx*yp/ry;cyp=-f*ry*xp/rx;cx=co*cxp-si*cyp+(x+nx)/2;cy=si*cxp+co*cyp+(y+ny)/2
            start=math.atan2((yp-cyp)/ry,(xp-cxp)/rx);end=math.atan2((-yp-cyp)/ry,(-xp-cxp)/rx);delta=end-start
            if sweep and delta<0:delta+=2*math.pi
            if not sweep and delta>0:delta-=2*math.pi
            # Subpixel linearization, max 5 degrees; exact endpoints retained.
            count=max(1,math.ceil(abs(delta)/(math.pi/36)))
            for j in range(1,count+1):
                a=start+delta*j/count;line(cx+co*rx*math.cos(a)-si*ry*math.sin(a),cy+si*rx*math.cos(a)+co*ry*math.sin(a))
            x,y=nx,ny
    return output

def main():
    out=['// Generated from Lucide 0.468.0. See Resources/Rewind/Lucide-LICENSE.txt.']
    for file in sorted((ROOT/'Research/lucide').glob('*.svg')):
        out.append('if ([name isEqualToString:@"'+file.stem+'"]) {')
        for el in ET.parse(file).getroot():
            tag=el.tag.split('}')[-1]; a=el.attrib
            if tag=='path':out+=path_code(a['d'])
            elif tag in ('polygon','polyline'):
                vals=list(map(float,re.findall(r'[-+]?\d*\.?\d+',a['points'])))
                out.append('CGContextMoveToPoint(c, %g, %g);'%tuple(vals[:2]))
                for j in range(2,len(vals),2):out.append('CGContextAddLineToPoint(c, %g, %g);'%tuple(vals[j:j+2]))
                if tag=='polygon':out.append('CGContextClosePath(c);')
            elif tag=='line':out+=['CGContextMoveToPoint(c, %s, %s);'%(a['x1'],a['y1']),'CGContextAddLineToPoint(c, %s, %s);'%(a['x2'],a['y2'])]
            elif tag=='circle':
                x,y,r=(float(a[k]) for k in ['cx','cy','r']);out.append('CGContextAddEllipseInRect(c, CGRectMake(%g, %g, %g, %g));'%(x-r,y-r,2*r,2*r))
            elif tag=='rect':out.append('CGContextAddPath(c, [UIBezierPath bezierPathWithRoundedRect:CGRectMake(%s, %s, %s, %s) cornerRadius:%s].CGPath);'%(a.get('x','0'),a.get('y','0'),a['width'],a['height'],a.get('rx','0')))
            else:raise ValueError(tag)
        out.append('}')
    (ROOT/'RewindIconPaths.inc').write_text('\n'.join(out)+'\n')
    print('Compiled',len(list((ROOT/'Research/lucide').glob('*.svg'))),'vector icons')

if __name__=='__main__':main()
