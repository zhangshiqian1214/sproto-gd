# sproto-gd
 这是一个专为godot引擎开发的sproto版本   
[云风的 c语言版 sproto](https://github.com/cloudwu/sproto)    
[js版sproto](https://https://github.com/zhangshiqian1214/sproto-js.git)   

#### 功能
---
- [x] 普通字符串 string
- [x] 二进制字符串binary
- [x] 最大32位整数integer
- [x] 符点数integer(n)
- [x] 布尔类型 boolean
- [x] 数组类型 *integer, *boolean, *string, *struct
- [x] 带索引的数组类型 *struct(key)
- [x] host 函数 
- [x] attach 函数
- [x] dispatch 函数 

#### spb 文件生成工具
[sprototool](https://github.com/zhangshiqian1214/sprototool.git) 

[spbtool](https://github.com/zhangshiqian1214/spbtool.git)


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
