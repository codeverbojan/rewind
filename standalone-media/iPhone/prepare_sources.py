"""Generate the initial compact-phone layout without modifying iPad sources."""
import hashlib
import json
import shutil
from pathlib import Path


def prepare(root, destination):
    destination.mkdir(parents=True, exist_ok=True)
    for source in root.iterdir():
        if source.is_file() and source.suffix in ['.m', '.mm', '.h', '.inc', '.cpp']:
            shutil.copy2(source, destination / source.name)
    edits = []

    def change(name, needle, replacement):
        path = destination / name
        text = path.read_text()
        assert text.count(needle) == 1, (name, 'baseline layout changed')
        path.write_text(text.replace(needle, replacement))
        edits.append({'file': name, 'needle': needle, 'replacement': replacement})

    change('RewindNavigation.inc',
        'self.navigationState=state;self.sidebar.frame=CGRectMake(0,0,w,84);self.navigationBrand.frame=CGRectMake(26,17,154,50);CGFloat start=w<900?184:226;',
        'BOOL compact=w<760;self.navigationState=state;self.sidebar.frame=CGRectMake(0,0,w,84);self.navigationBrand.frame=compact?CGRectMake(16,0,154,44):CGRectMake(26,17,154,50);CGFloat start=w<900?184:226;')
    change('RewindNavigation.inc',
        'button.frame=CGRectMake(start+i*82,18,78,48);button.titleLabel.font=[UIFont systemFontOfSize:14 weight:',
        'CGFloat cell=(w-16)/5;button.frame=compact?CGRectMake(8+i*cell,40,cell,44):CGRectMake(start+i*82,18,78,48);[button viewWithTag:7101].frame=compact?CGRectMake((cell-24)/2,41,24,2):CGRectMake(23,48,25,2);button.titleLabel.font=[UIFont systemFontOfSize:compact?12:14 weight:')
    change('RewindNavigation.inc',
        'self.navigationSearch.frame=CGRectMake(w-130,19,48,48);self.navigationProfile.frame=CGRectMake(w-74,19,48,48);',
        'self.navigationSearch.frame=compact?CGRectMake(w-108,0,44,44):CGRectMake(w-130,19,48,48);self.navigationProfile.frame=compact?CGRectMake(w-56,4,36,36):CGRectMake(w-74,19,48,48);')
    change('RewindProfiles.inc',
        'columns=MIN(total,(NSUInteger)(w<900?3:4));CGFloat tile=146,gap=30;',
        'columns=MIN(total,(NSUInteger)(w<600?2:(w<900?3:4)));CGFloat tile=146,gap=w<600?18:30;')
    change('RewindProfiles.inc', 'width:w-64 size:42 weight:UIFontWeightRegular',
        'width:w-64 size:w<600?28:42 weight:UIFontWeightRegular')
    change('RewindPlayer.m',
        'self.qualityButton.frame=CGRectMake(w-462,h-79,118,48);',
        '''self.qualityButton.frame=CGRectMake(w-462,h-79,118,48);
    if(w<700){
        self.closeButton.frame=CGRectMake(12,16,44,44);self.keepButton.frame=CGRectMake(w-132,16,120,44);
        self.titleLabel.frame=CGRectMake(68,16,MAX(1,w-212),34);self.titleLabel.font=[UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
        self.statusLabel.frame=CGRectMake(68,54,w-84,40);
        self.backward.frame=CGRectMake(w/2-146,h/2-32,64,64);self.forward.frame=CGRectMake(w/2+82,h/2-32,64,64);
        self.scrubber.frame=CGRectMake(16,h-154,w-32,44);self.bufferedTrack.frame=CGRectMake(18,h-133,w-36,2);
        self.timeLabel.frame=CGRectMake(20,h-112,w-40,24);CGFloat cell=(w-32)/4;
        NSArray *actions=@[self.qualityButton,self.audioButton,self.restart,self.captions];
        for(NSUInteger i=0;i<actions.count;i++){RWButton *button=actions[i];button.frame=CGRectMake(16+i*cell,h-76,cell,44);button.titleLabel.font=[UIFont systemFontOfSize:12 weight:UIFontWeightMedium];}
        self.skipIntro.frame=CGRectMake(w-178,h-218,158,48);self.nextEpisodeButton.frame=CGRectMake(w-238,h-218,218,48);
        self.storeButton.frame=CGRectMake(w-160,h-166,144,44);self.bottomShade.frame=CGRectMake(0,h-220,w,220);
        [self layoutSubtitle];
    }else{self.titleLabel.font=[UIFont systemFontOfSize:21 weight:UIFontWeightSemibold];}
''')
    return {'edits': edits, 'source_sha256': {
        p.name: hashlib.sha256(p.read_bytes()).hexdigest()
        for p in destination.iterdir() if p.is_file()}}
