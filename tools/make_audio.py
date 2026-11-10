"""Original lightweight synthesized feedback, no downloaded audio."""
import wave,math,random
from pathlib import Path
out=Path(__file__).resolve().parents[1]/'assets/audio'
sr=22050;random.seed(414)
def make(name,duration,fn):
 data=bytearray()
 for i in range(int(sr*duration)):
  t=i/sr;s=max(-1,min(1,fn(t,duration)));v=int(s*30000);data.extend(v.to_bytes(2,'little',signed=True))
 with wave.open(str(out/(name+'.wav')),'wb') as f:f.setnchannels(1);f.setsampwidth(2);f.setframerate(sr);f.writeframes(data)
def tone(f,t):return math.sin(math.tau*f*t)
make('swing',.24,lambda t,d:random.uniform(-1,1)*math.sin(math.pi*t/d)**2*.23+tone(260-700*t,t)*math.exp(-t*18)*.08)
make('dodge',.3,lambda t,d:random.uniform(-1,1)*math.sin(math.pi*t/d)*.10)
make('hit',.2,lambda t,d:(random.uniform(-1,1)*.23+tone(100,t)*.3)*math.exp(-t*26))
make('hurt',.35,lambda t,d:(tone(105-t*160,t)+tone(65,t)*.4)*math.exp(-t*12)*.28)
make('slime',.32,lambda t,d:tone(150+600*t,t)*math.exp(-t*15)*.26)
make('warning',.65,lambda t,d:tone(220,t)*math.sin(math.pi*t/d)**2*.17+tone(330,t)*math.sin(math.pi*t/d)*.09)
make('chime',1.8,lambda t,d:sum(tone(f,max(0,t-j*.12))*math.exp(-max(0,t-j*.12)*3)*(1-math.exp(-max(0,t-j*.12)*40))*.16 for j,f in enumerate([523.25,659.25,783.99,1046.5])))
make('heal',1.,lambda t,d:(tone(659.25,t)*.12+tone(987.77,t)*.1)*math.exp(-t*4)*(1-math.exp(-t*30)))
print('AUDIO_READY')
