"""Differential checks against Python oracles; generate UART acceptance vectors."""
from pathlib import Path
import ctypes as c, json, math, random, re, subprocess
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'build'
def cases():
    vectors=[]
    def add(command, *patterns): vectors.append(dict(command=command,patterns=list(patterns)))
    add('info',r'^CPU=SimpleRV32I ISA=RV32I CLOCK=13500000 ROM=16384 RAM=1024$')
    add('ping',r'^PONG$')
    for a in ([9,-2,5,1],[1,2,3,4,5],list(range(16,0,-1)),[4]*16,[-1000000,1000000,0],[-1]):
        add('sort '+' '.join(map(str,a)), '^SORT '+re.escape(' '.join(map(str,sorted(a))))+'$',
            r'^INSERT comparisons=\d+ moves=\d+ cycles=[1-9]\d* instructions=[1-9]\d*$',
            r'^BUBBLE comparisons=\d+ moves=\d+ cycles=[1-9]\d* instructions=[1-9]\d*$')
    for target,a in ((5,[1,3,5,7]),(2,[1,3,5,7]),(-9,[-9]),(1000000,[-1000000,0,1000000])):
        index=a.index(target) if target in a else -1
        add('find '+str(target)+' '+' '.join(map(str,a)),rf'^FIND index={index} cycles=[1-9]\d* instructions=[1-9]\d*$')
    for a in ([-2,1,-3,4,-1,2,1,-5,4],[-8,-3,-6,-2,-5,-4],[0,0,0],list(range(1,17))):
        best=max(sum(a[i:j+1]) for i in range(len(a)) for j in range(i,len(a)))
        add('maxsub '+' '.join(map(str,a)),rf'^MAXSUB sum={best} left=\d+ right=\d+ cycles=[1-9]\d* instructions=[1-9]\d*$')
    for a,b in ((48,18),(0,0),(0,10),(1000000,999999),(1024,256),(27,81)):
        add(f'gcd {a} {b}',rf'^GCD value={math.gcd(a,b)} cycles=[1-9]\d* instructions=[1-9]\d*$')
    for command in ('sort','find 3 9 1','gcd -1 5','sort 1000001','sort 1x',
                    'unknown','sort '+' '.join(['1']*17),'gcd 1','maxsub'):
        add(command,r'^ERR .+$')
    add('gcd 48 18',r'^GCD value=6 cycles=[1-9]\d* instructions=[1-9]\d*$')
    return vectors
def main():
    OUT.mkdir(exist_ok=True)
    so=OUT/'algorithms.so'
    subprocess.run(['gcc','-std=c11','-O1','-g','-shared','-fPIC','-Wall','-Wextra','-Werror',
        '-fsanitize=undefined','-fno-sanitize-recover=all','firmware/algorithms.c','-o',str(so)],cwd=ROOT,check=True)
    lib=c.CDLL(str(so))
    class Stats(c.Structure): _fields_=[('comparisons',c.c_uint32),('moves',c.c_uint32)]
    class Result(c.Structure): _fields_=[('sum',c.c_int32),('left',c.c_uint32),('right',c.c_uint32)]
    for name in ('insertion_sort','bubble_sort'):
        getattr(lib,name).argtypes=[c.POINTER(c.c_int32),c.c_uint32,c.POINTER(Stats)]
    lib.binary_search.argtypes=[c.POINTER(c.c_int32),c.c_uint32,c.c_int32];lib.binary_search.restype=c.c_int32
    lib.max_subarray.argtypes=[c.POINTER(c.c_int32),c.c_uint32];lib.max_subarray.restype=Result
    lib.binary_gcd.argtypes=[c.c_uint32,c.c_uint32];lib.binary_gcd.restype=c.c_uint32
    rng=random.Random(20261115);checked=0
    for _ in range(700):
        n=rng.randrange(1,17);a=[rng.randrange(-1000000,1000001) for _ in range(n)]
        for name in ('insertion_sort','bubble_sort'):
            guarded=(c.c_int32*(n+2))(123456789,*a,-123456789);stats=Stats()
            ptr=c.cast(c.byref(guarded,4),c.POINTER(c.c_int32))
            getattr(lib,name)(ptr,n,c.byref(stats))
            assert list(guarded)[1:-1]==sorted(a) and guarded[0]==123456789 and guarded[n+1]==-123456789
            checked+=1
        array=(c.c_int32*n)(*a);result=lib.max_subarray(array,n)
        best=max(sum(a[i:j+1]) for i in range(n) for j in range(i,n))
        assert result.sum==best and 0<=result.left<=result.right<n and sum(a[result.left:result.right+1])==best
        checked+=1
        ordered=sorted(a);array=(c.c_int32*n)(*ordered)
        for target in (a[0],rng.randrange(-1000000,1000001)):
            at=lib.binary_search(array,n,target)
            assert (at==-1 and target not in ordered) or (0<=at<n and ordered[at]==target)
            checked+=1
        a,b=rng.randrange(0,1000001),rng.randrange(0,1000001)
        assert lib.binary_gcd(a,b)==math.gcd(a,b);checked+=1
    for a,b in ((0,0),(0,10),(10,0),(1000000,999999)):
        assert lib.binary_gcd(a,b)==math.gcd(a,b);checked+=1
    vectors=cases()
    (OUT/'hardware-vectors.json').write_text(json.dumps(vectors,indent=2)+'\n')
    (OUT/'algorithm-tests.json').write_text(json.dumps(dict(result='PASS',differential_checks=checked,uart_cases=len(vectors),ubsan=True),indent=2)+'\n')
    print(f'Algorithm checks PASS: {checked}; UART cases: {len(vectors)}')
if __name__=='__main__': main()
