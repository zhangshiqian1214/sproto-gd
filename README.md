# sproto-gd
Gdscript版本的sproto库


# 性能测试
```gdscript
var player = {
		"playerid" :  0xFFFFFFFF,
		"nickname" : "helloworld0123456789abcdefg",
		"headid"   : 1001,
		"headurl"  : "http://img5.duitang.com/uploads/item/201410/17/20141017235209_MEsRe.thumb.700_0.jpeg",
		"sex"      : 0,
		"isvip"    : true,
		"gold"     : 4147483647,
		"signs"    : [false, false, true, false, true],
		"pets"     : [10038, 10039, 10040, 10041, 10042],
		"mails"    : ["hello", "world", "how", "are", "you"],
		"master"   : { "playerid" : 12345, "nickname" : "李飞haha"},
		"friends"  : [
        	{ "playerid" : 1001, "nickname" : "小张"}, 
        	{ "playerid" : 1002, "nickname" : "小王"},
        	{ "playerid" : 1003, "nickname" : "小飞"},
        	{ "playerid" : 1004, "nickname" : "小龙"}
    	]
	}
	
	for i in range(1000000):
		var buffer = sproto.encode("auth.Player", player)
		var result = sproto.decode("auth.Player", buffer)
```		
	
	同时运行1M次做比较
	lua   17秒
	js    133秒
	gd    1780秒
