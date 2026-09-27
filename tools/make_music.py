"""Original 16-bar chiptune for Pay the Price. Standard-library PCM synthesis."""
import math, random, wave, struct
from pathlib import Path
RATE=22050
BPM=112
BEAT=60/BPM
LENGTH=64*BEAT
track=[0.0]*round(RATE*LENGTH)
rng=random.Random(2026)
def note(midi): return 440*2**((midi-69)/12)
def add(at,duration,freq,amp,kind):
    first=round(at*RATE); count=round(duration*RATE)
    for i in range(count):
        t=i/RATE; p=t/duration
        env=min(1,t/.008)*min(1,(duration-t)/.035)
        if kind=='bass': value=math.sin(math.tau*freq*t)+.28*math.sin(math.tau*freq*2*t)
        elif kind=='lead': value=sum(math.sin(math.tau*freq*h*t)/h for h in (1,3,5))/1.53
        elif kind=='arp': value=(2/math.pi)*math.asin(math.sin(math.tau*freq*t))*(1-p)**1.5
        elif kind=='kick': value=math.sin(math.tau*(48*t+50*.018*(1-math.exp(-t/.018))))*math.exp(-t*22)
        elif kind=='snare': value=(rng.uniform(-1,1)*.75+math.sin(math.tau*190*t)*.25)*math.exp(-t*24)
        else: value=rng.uniform(-1,1)*math.exp(-t*90)
        if first+i<len(track): track[first+i]+=value*amp*env
chords=[(45,57,60,64),(41,53,57,60),(48,55,60,64),(43,55,59,62)]
melody=[[69,None,72,76,74,72,69,None],[65,None,69,72,69,67,65,None],[67,72,None,76,79,76,72,67],[67,None,71,74,72,71,67,None]]
for bar in range(16):
    root,*chord=chords[(bar//2)%4]
    base=bar*4*BEAT
    for beat in range(4):
        add(base+beat*BEAT,BEAT*.78,note(root if beat%2==0 else root+7),.14,'bass')
        if beat%2==0: add(base+beat*BEAT,.22,0,.20,'kick')
        else: add(base+beat*BEAT,.18,0,.11,'snare')
    for half in range(8):
        add(base+half*BEAT/2,.055,0,.033 if half%2==0 else .055,'hat')
        add(base+half*BEAT/2,BEAT*.43,note(chord[half%3]+12),.065,'arp')
        n=melody[(bar//2)%4][(half+(2 if bar%2 else 0))%8]
        if n and (bar>=4 or half%2==0): add(base+half*BEAT/2,BEAT*.40,note(n+(12 if bar>=12 and half%4==0 else 0)),.11,'lead')
peak=max(abs(v) for v in track)
path=Path(__file__).resolve().parents[1]/'assets/audio/price_of_living.wav'
with wave.open(str(path),'wb') as wav:
    wav.setnchannels(1);wav.setsampwidth(2);wav.setframerate(RATE)
    wav.writeframes(b''.join(struct.pack('<h',round(v/peak*24500)) for v in track))
print(f'{path.name}: {LENGTH:.2f}s, {BPM} BPM, peak normalized to -2.5 dBFS')
