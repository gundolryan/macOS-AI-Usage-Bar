#!/usr/bin/env python3
"""Read subscription quota through the installed Claude Code process."""
import datetime, json, os, selectors, shutil, subprocess, time

def main():
    exe = shutil.which('claude')
    if not exe:
        return {'error': 'Claude Code CLI를 찾을 수 없습니다.'}
    p = subprocess.Popen([exe, '-p', '--input-format', 'stream-json', '--output-format', 'stream-json', '--verbose', '--no-session-persistence', '--safe-mode', '--tools', '', '--strict-mcp-config'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=0)
    try:
        def send(o):
            p.stdin.write((json.dumps(o)+'\n').encode()); p.stdin.flush()
        send({'type':'control_request','request_id':'init','request':{'subtype':'initialize','hooks':{}}})
        send({'type':'control_request','request_id':'usage','request':{'subtype':'get_usage','skip_behaviors':True}})
        sel=selectors.DefaultSelector(); sel.register(p.stdout,selectors.EVENT_READ); buf=b''; deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            if not sel.select(max(0,deadline-time.monotonic())): break
            chunk=os.read(p.stdout.fileno(),65536)
            if not chunk: break
            buf+=chunk
            while b'\n' in buf:
                line,buf=buf.split(b'\n',1)
                try: obj=json.loads(line)
                except (ValueError,UnicodeDecodeError): continue
                if obj.get('type')!='control_response': continue
                response=obj.get('response') or {}
                if response.get('request_id') != 'usage': continue
                if response.get('subtype') != 'success': return {'error':'Claude 사용량 조회에 실패했습니다.'}
                payload=response.get('response') or {}; rates=payload.get('rate_limits') or {}; windows={}
                for key in ('five_hour','seven_day'):
                    entry=rates.get(key)
                    if not isinstance(entry,dict) or not isinstance(entry.get('utilization'),(float,int)): continue
                    reset=entry.get('resets_at'); stamp=None
                    if reset:
                        try: stamp=datetime.datetime.fromisoformat(reset.replace('Z','+00:00')).timestamp()
                        except (ValueError,TypeError): pass
                    windows[key]={'used_percentage':entry['utilization'],'resets_at':stamp}
                if not windows: return {'error':'Claude 한도 정보가 없습니다. Claude Code 로그인과 구독을 확인하세요.'}
                return {'rate_limits':windows, 'updated_at':time.time()}
        return {'error':'Claude Code 응답 시간이 초과되었습니다.'}
    finally:
        p.terminate()
        try: p.wait(timeout=2)
        except subprocess.TimeoutExpired: p.kill(); p.wait()
try:
    print(json.dumps(main(), ensure_ascii=False))
except Exception:
    print(json.dumps({'error':'Claude Code 연결을 시작할 수 없습니다.'}, ensure_ascii=False))
