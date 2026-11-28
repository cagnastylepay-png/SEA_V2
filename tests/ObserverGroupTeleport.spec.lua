return function(source)
 local first=assert(source:find('O.SpreadRetryAt=0',1,true))
 local last=assert(source:find('function O.Status(status,good)',first,true))
 local section=source:sub(first,last-1)
 local observer={Destroyed=false,ClientKind='observer'}
 local env=setmetatable({
  O=observer,player={UserId=7},
  game={PlaceId=123,JobId='caylus-job'},
 },{__index=getfenv()})
 local chunk=assert(loadstring(section));setfenv(chunk,env);chunk()
 observer.ReceiveSpread({placeId='123',jobId='caylus-job',destinationPlaceId='456',destinationJobId='admin-job',delaySeconds=0},true,true)
 assert(observer.SpreadTarget and observer.SpreadTarget.destinationPlaceId=='456','cross-place Admin destination is retained')
 assert(observer.SpreadTarget.destinationJobId=='admin-job','Admin job is retained')
 observer.SpreadTarget=nil
 observer.ReceiveSpread({placeId='123',jobId='caylus-job',destinationJobId='same-place-job',delaySeconds=0},true)
 assert(observer.SpreadTarget and observer.SpreadTarget.destinationPlaceId=='123','legacy same-place targets remain supported')
 assert(section:find('TeleportToPlaceInstance(tonumber(target.destinationPlaceId)',1,true),'teleport must use Admin place ID')
 return 'Observer group teleport passed: cross-place and legacy same-place destinations are validated and retained.'
end
