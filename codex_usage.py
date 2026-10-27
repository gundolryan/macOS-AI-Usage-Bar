#!/usr/bin/env python3
import json, os, selectors, shutil, subprocess, sys, time

def main():
    exe = shutil.which('codex')
    if not exe:
        print(json.dumps({'error': 'Codex CLI를 찾을 수 없습니다.'})); return
    proc = subprocess.Popen([exe, 'app-server', '--listen', 'stdio://'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
    try:
        def send(obj):
            proc.stdin.write((json.dumps(obj)+'\n').encode()); proc.stdin.flush()
        send({'id':1,'method':'initialize','params':{'clientInfo':{'name':'quota_pet','title':'Quota Pet','version':'1.0.0'}}})
        selector = selectors.DefaultSelector(); selector.register(proc.stdout, selectors.EVENT_READ)
        buf=b''; deadline=time.monotonic()+15
        while time.monotonic()<deadline:
            if not selector.select(max(0, deadline-time.monotonic())): break
            chunk=os.read(proc.stdout.fileno(), 65536)
            if not chunk: break
            buf+=chunk
            while b'\n' in buf:
                line,buf=buf.split(b'\n',1)
                try: message=json.loads(line)
                except (ValueError, UnicodeDecodeError): continue
                if message.get('id')==1:
                    if 'error' in message: raise RuntimeError('Codex 초기화에 실패했습니다.')
                    send({'method':'initialized','params':{}})
                    send({'id':2,'method':'account/rateLimits/read'})
                elif message.get('id')==2:
                    if 'error' in message: raise RuntimeError('Codex 사용량을 읽을 수 없습니다. 로그인 상태를 확인하세요.')
                    result=message.get('result') or {}
                    buckets=result.get('rateLimitsByLimitId') or {}
                    quota=buckets.get('codex') or result.get('rateLimits') or {}
                    print(json.dumps({'rateLimits':quota,'updated_at':time.time()})); return
        raise RuntimeError('Codex 응답 시간이 초과되었습니다.')
    except Exception as exc:
        print(json.dumps({'error':str(exc)}))
    finally:
        proc.terminate()
        try: proc.wait(timeout=2)
        except subprocess.TimeoutExpired: proc.kill(); proc.wait()
if __name__=='__main__': main()
