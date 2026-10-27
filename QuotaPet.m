#import <Cocoa/Cocoa.h>
@interface App : NSObject <NSApplicationDelegate>
@property NSStatusItem *item;
@property NSDictionary *codex;
@property NSDictionary *claude;
@property BOOL loading;
@property BOOL claudeLoading;
@property NSDate *lastClaudeAttempt;
@property NSString *claudeError;
@end
@implementation App
- (void)applicationDidFinishLaunching:(NSNotification *)n {
 self.item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];
 self.codex=@{}; self.claude=@{}; [self refresh];
 [NSTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(refresh) userInfo:nil repeats:YES];
}
- (void)refresh {
 [self updateMenu]; [self refreshClaude]; if (self.loading) return; self.loading=YES;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
  NSTask *task=[NSTask new]; task.executableURL=[NSURL fileURLWithPath:@"/usr/bin/python3"];
  task.arguments=@[[[NSBundle mainBundle] pathForResource:@"codex_usage" ofType:@"py"]];
  NSMutableDictionary *env=[NSProcessInfo.processInfo.environment mutableCopy]; env[@"PATH"]=[NSString stringWithFormat:@"%@/.local/bin:%@/bin:%@/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:%@", NSHomeDirectory(), NSHomeDirectory(), NSHomeDirectory(), env[@"PATH"] ?: @""]; task.environment=env;
  NSPipe *pipe=[NSPipe pipe]; task.standardOutput=pipe; task.standardError=[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
  NSError *error=nil; NSDictionary *result=nil;
  if ([task launchAndReturnError:&error]) { NSData *d=[pipe.fileHandleForReading readDataToEndOfFile]; [task waitUntilExit]; result=[NSJSONSerialization JSONObjectWithData:d options:0 error:nil]; }
  if (![result isKindOfClass:NSDictionary.class]) result=@{@"error":@"Codex 연결을 시작할 수 없습니다."};
  NSDictionary *output=result; dispatch_async(dispatch_get_main_queue(), ^{ self.codex=output; self.loading=NO; [self updateMenu]; });
 });
}
- (void)refreshClaude {
 if (self.claudeLoading || (self.lastClaudeAttempt && -self.lastClaudeAttempt.timeIntervalSinceNow < 60)) return;
 self.claudeLoading=YES; self.lastClaudeAttempt=NSDate.date;
 dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY,0), ^{
  NSTask *task=[NSTask new]; task.executableURL=[NSURL fileURLWithPath:@"/usr/bin/python3"];
  task.arguments=@[[[NSBundle mainBundle] pathForResource:@"claude_usage" ofType:@"py"]];
  NSMutableDictionary *env=[NSProcessInfo.processInfo.environment mutableCopy]; env[@"PATH"]=[NSString stringWithFormat:@"%@/.local/bin:%@/bin:%@/.npm-global/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:%@", NSHomeDirectory(), NSHomeDirectory(), NSHomeDirectory(), env[@"PATH"] ?: @""]; task.environment=env;
  NSPipe *pipe=[NSPipe pipe]; task.standardOutput=pipe; task.standardError=[NSFileHandle fileHandleForWritingAtPath:@"/dev/null"];
  NSDictionary *result=nil; NSError *error=nil;
  if ([task launchAndReturnError:&error]) { NSData *data=[pipe.fileHandleForReading readDataToEndOfFile]; [task waitUntilExit]; result=[NSJSONSerialization JSONObjectWithData:data options:0 error:nil]; }
  if (![result isKindOfClass:NSDictionary.class]) result=@{@"error":@"Claude 연결을 시작할 수 없습니다."};
  NSDictionary *output=result; dispatch_async(dispatch_get_main_queue(), ^{
   self.claudeLoading=NO; self.claudeError=output[@"error"];
   if ([output[@"rate_limits"] isKindOfClass:NSDictionary.class]) self.claude=output;
   [self updateMenu];
  });
 });
}
- (void)manualRefresh { self.lastClaudeAttempt=nil; [self refresh]; }
- (NSString *)age:(NSNumber *)n {
 if (![n isKindOfClass:NSNumber.class]) return @"갱신 기록 없음";
 NSInteger s=MAX(0,(NSInteger)(NSDate.date.timeIntervalSince1970-n.doubleValue));
 if (s<60) return @"방금 갱신"; if (s<3600) return [NSString stringWithFormat:@"%ld분 전 갱신",(long)(s/60)];
 return [NSString stringWithFormat:@"%ld시간 전 갱신 · 오래된 정보일 수 있음",(long)(s/3600)];
}
- (NSString *)used:(NSNumber *)n { if (![n isKindOfClass:NSNumber.class]) return @"–"; return [NSString stringWithFormat:@"%.0f%%",MAX(0,MIN(100,n.doubleValue))]; }
- (NSString *)countdown:(id)value {
 if (![value isKindOfClass:NSNumber.class] || [value doubleValue] <= 0) return @"–";
 NSTimeInterval remaining=[value doubleValue]-NSDate.date.timeIntervalSince1970;
 if (remaining <= 0) return @"갱신 중";
 NSInteger minutes=(NSInteger)ceil(remaining/60.0);
 NSInteger days=minutes/1440, hours=(minutes%1440)/60, mins=minutes%60;
 if (days > 0) return [NSString stringWithFormat:@"%ldD %ldH %ldM",(long)days,(long)hours,(long)mins];
 return [NSString stringWithFormat:@"%ldH %ldM",(long)hours,(long)mins];
}
- (NSString *)window:(NSString *)name data:(NSDictionary *)data pct:(NSString *)pct reset:(NSString *)reset {
 NSNumber *n=data[pct]; if (![n isKindOfClass:NSNumber.class]) return [NSString stringWithFormat:@"  %@  ·  정보 없음",name];
 NSNumber *stamp=data[reset]; NSString *when=@"갱신 시각 정보 없음";
 if ([stamp isKindOfClass:NSNumber.class] && stamp.doubleValue>0) { NSDateFormatter *f=[NSDateFormatter new]; f.locale=[[NSLocale alloc] initWithLocaleIdentifier:@"ko_KR"]; f.dateFormat=@"M월 d일 HH:mm"; when=[@"초기화 " stringByAppendingString:[f stringFromDate:[NSDate dateWithTimeIntervalSince1970:stamp.doubleValue]]]; }
 double used=MAX(0,MIN(100,n.doubleValue)); return [NSString stringWithFormat:@"  %@  ·  사용 %.0f%%  ·  %@",name,used,when];
}
- (void)line:(NSString *)s menu:(NSMenu *)menu { NSMenuItem *i=[[NSMenuItem alloc] initWithTitle:s action:nil keyEquivalent:@""]; i.enabled=NO; [menu addItem:i]; }
- (void)updateBadge:(NSString *)claude codex:(NSString *)codex {
 NSFont *font=[NSFont monospacedDigitSystemFontOfSize:11 weight:NSFontWeightSemibold];
 NSDictionary *attrs=@{NSFontAttributeName:font, NSForegroundColorAttributeName:NSColor.whiteColor};
 NSSize cSize=[claude sizeWithAttributes:attrs], xSize=[codex sizeWithAttributes:attrs];
 CGFloat cWidth=ceil(cSize.width)+16, xWidth=ceil(xSize.width)+16, gap=4;
 NSSize size=NSMakeSize(cWidth+xWidth+gap, 22);
 NSImage *badge=[NSImage imageWithSize:size flipped:NO drawingHandler:^BOOL(NSRect bounds) {
  NSRect cBox=NSMakeRect(0,2,cWidth,18), xBox=NSMakeRect(cWidth+gap,2,xWidth,18);
  NSBezierPath *cPath=[NSBezierPath bezierPathWithRoundedRect:cBox xRadius:5 yRadius:5];
  NSBezierPath *xPath=[NSBezierPath bezierPathWithRoundedRect:xBox xRadius:5 yRadius:5];
  [[NSColor colorWithCalibratedRed:0.64 green:0.27 blue:0.13 alpha:1] setFill]; [cPath fill];
  [[NSColor colorWithCalibratedRed:0.36 green:0.19 blue:0.61 alpha:1] setFill]; [xPath fill];
  [claude drawAtPoint:NSMakePoint(8,(bounds.size.height-cSize.height)/2) withAttributes:attrs];
  [codex drawAtPoint:NSMakePoint(cWidth+gap+8,(bounds.size.height-xSize.height)/2) withAttributes:attrs];
  return YES;
 }];
 badge.template=NO; self.item.button.title=@""; self.item.button.image=badge;
 self.item.button.imagePosition=NSImageOnly;
 self.item.button.toolTip=nil;
}
- (void)updateMenu {
 NSMenu *m=[NSMenu new]; [self line:@"AI 사용량  ·  세션 / 주간" menu:m]; [m addItem:NSMenuItem.separatorItem];
 [self line:[@"Claude Code  ·  " stringByAppendingString:[self age:self.claude[@"updated_at"]]] menu:m];
 NSDictionary *rates=self.claude[@"rate_limits"] ?: @{};
 [self line:[self window:@"5시간" data:rates[@"five_hour"] pct:@"used_percentage" reset:@"resets_at"] menu:m];
 [self line:[self window:@"주간" data:rates[@"seven_day"] pct:@"used_percentage" reset:@"resets_at"] menu:m];
 if (self.claudeError) [self line:[@"  " stringByAppendingString:self.claudeError] menu:m];
 else if (!self.claude.count) [self line:@"  Claude 사용량을 불러오는 중…" menu:m];
 [m addItem:NSMenuItem.separatorItem]; [self line:[@"Codex  ·  " stringByAppendingString:[self age:self.codex[@"updated_at"]]] menu:m];
 NSDictionary *q=self.codex[@"rateLimits"];
 if (self.codex[@"error"]) [self line:[@"  " stringByAppendingString:self.codex[@"error"]] menu:m];
 else if ([q isKindOfClass:NSDictionary.class]) {
  BOOL found=NO; for (NSString *key in @[@"primary",@"secondary"]) { NSDictionary *d=q[key]; if (![d isKindOfClass:NSDictionary.class]) continue; found=YES; NSNumber *minutes=d[@"windowDurationMins"]; NSString *label=@"한도"; if ([minutes isKindOfClass:NSNumber.class]) { NSInteger v=minutes.integerValue; if (v>=10080 && v%1440==0) label=[NSString stringWithFormat:@"%ld일",(long)(v/1440)]; else if (v>=60 && v%60==0) label=[NSString stringWithFormat:@"%ld시간",(long)(v/60)]; else label=[NSString stringWithFormat:@"%ld분",(long)v]; } [self line:[self window:label data:d pct:@"usedPercent" reset:@"resetsAt"] menu:m]; }
  if (!found) [self line:@"  사용량 정보 없음 · 로그인 상태를 확인하세요" menu:m];
 } else [self line:@"  불러오는 중…" menu:m];
 [m addItem:NSMenuItem.separatorItem]; NSMenuItem *refresh=[[NSMenuItem alloc] initWithTitle:@"지금 새로고침" action:@selector(manualRefresh) keyEquivalent:@"r"]; refresh.target=self; [m addItem:refresh];
 [m addItem:[[NSMenuItem alloc] initWithTitle:@"종료" action:@selector(terminate:) keyEquivalent:@"q"]]; self.item.menu=m;
 NSNumber *updated=self.claude[@"updated_at"]; BOOL stale=[updated isKindOfClass:NSNumber.class] && NSDate.date.timeIntervalSince1970-updated.doubleValue >= 3600;
 NSString *claudeText=[NSString stringWithFormat:@"Claude Code [%@ / %@%@ / %@]",[self used:rates[@"five_hour"][@"used_percentage"]],[self used:rates[@"seven_day"][@"used_percentage"]],stale ? @"!" : @"",[self countdown:rates[@"seven_day"][@"resets_at"]]];
 NSString *codexText=[NSString stringWithFormat:@"Codex [%@ / %@ / %@]",[self used:q[@"primary"][@"usedPercent"]],[self used:q[@"secondary"][@"usedPercent"]],[self countdown:q[@"secondary"][@"resetsAt"]]];
 [self updateBadge:claudeText codex:codexText];
}
@end
int main(int argc, const char *argv[]) { @autoreleasepool { NSApplication *app=NSApplication.sharedApplication; App *delegate=[App new]; app.delegate=delegate; [app setActivationPolicy:NSApplicationActivationPolicyAccessory]; [app run]; } return 0; }
