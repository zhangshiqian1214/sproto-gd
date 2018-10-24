extends Node

var Sproto = preload("res://sproto.gd")

# class member variables go here, for example:
# var a = 2
# var b = "textvar"

func _ready():
	# Called when the node is added to the scene for the first time.
	# Initialization here
	pass

#func _process(delta):
#	# Called every frame. Delta is time since last frame.
#	# Update game logic here.
#	pass


class Buffer:
	var buffer = []
	var index = 0
	func init(arr):
		buffer = Array(arr)
	func move(size):
		index = index + size
	func size():
		return buffer.size()
	func set(value):
		buffer[index] = value
	func pointer(other, idx=0):
		buffer = other.buffer
		index = other.index + idx
	func slice(idx, sz):
		var result = []
		if index + idx > buffer.size() - 1:
			return result
		if index + idx + sz > buffer.size() - 1:
			sz = buffer.size() - 1 - index - idx
		result.resize(sz+1)
		for i in range(sz):
			result[i] = buffer[index+idx+i]
		return result
	func get_string_from_utf8(idx, sz):
		var resultArr = slice(idx, sz)
		return PoolByteArray(resultArr).get_string_from_utf8()
	func splice(idx, sz):
		if sz == 0:
			return
		var begin = idx + index
		if begin > buffer.size():
			return
		if sz > buffer.size() - begin - 1:
			sz = buffer.size() - begin - 1
		for i in range(sz):
			buffer.remove(index+idx)
		return sz

func test(buf):
	buf.move(3)
	#buf.set(100)
	pass
	
func test1(buf):
	buf.move(1)
	test(buf)
	pass
	
func test2(buf):
	#buf.move(2)
	#test1(buf)
	
	var tmpBuf = Buffer.new()
	tmpBuf.pointer(buf, 0)
	buf = tmpBuf
	
	tmpBuf.set(87)
	print(tmpBuf.get_string_from_utf8(0, 5))
	tmpBuf.move(3)
	
	pass


func _on_Button_pressed():
	var buf = Buffer.new()
	buf.init([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x00])
	#buf.init([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x00])
	#var buf1 = Buffer.new()
	#buf1.pointer(buf)
	#test2(buf)
	#print(buf.buffer)
	#print(buf.index)

	#buf.splice(5, 5)
	#print(buf.get_string_from_utf8(0, buf.size()))
	
	#buf1.move(1)
	#buf1.set(128)
	#print(buf.buffer)
	#print(buf.index)
	
	#var bytes = buf.slice(0,13)
	#var bytesArr = PoolByteArray(bytes)
	#var ss = bytesArr.get_string_from_utf8()
	#print(ss)
	#print(buf.get_string_from_utf8(0, 5))
	
	var dict = {}
	if dict.has("auth.Player") == true:
		print("auth.Player is null")

	var sproto = Sproto.new()
	sproto.create_from_spb("res://protocol.spb")
	
	"""
	.Player {
		playerid   0 : integer            #玩家id               ok
		nickname   1 : string             #昵称                 ok (size > 128重新分配空间)
		headid     2 : integer            #默认头像id            ok
		headurl    3 : string             #头像地址              ok
		sex        4 : integer            #0-未知 1-男 2-女      ok
		isvip      5 : boolean            #是否是vip            ok
		gold       6 : integer            #金币                 ok
		signs      7 : *boolean           #签到列表              ok
		pets       8 : *integer           #宠物id               ok
		mails      9 : *string            #邮件列表              ok
		friends   10 : *Friend(playerid)  #带playerid键值        ok
		money     11 : integer(2)         #带2位小数的货币        ok
	}
	integer <= 2147483647
	
	"""
	
	var player = {
		"playerid" :  0xFFFFFFFF,
		"nickname" : "helloworld0123456789abcdefg",
		"headid"   : 1001,
		"headurl"  : "http://img5.duitang.com/uploads/item/201410/17/20141017235209_MEsRe.thumb.700_0.jpeg",
		"sex"      : 0,
		"isvip"    : true,
		"gold"     : 2147483647,
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
	var date = OS.get_date()
	var time = OS.get_time()
	var timeZone = OS.get_time_zone_info()
	var dtime = OS.get_datetime()
	var unixdt = OS.get_unix_time()
	var syssec = OS.get_system_time_secs()
	#var udt = OS.get_datetime_from_unix_time()
	
	var buffer = sproto.encode("auth.Player", player)
	var pbuffer = sproto.pack(buffer)
	var ubuffer = sproto.unpack(pbuffer)
	
	var result = sproto.decode("auth.Player", ubuffer)
	
	#for i in range(100000):
	#	var outstr = JSON.print(player)
	#	var result = JSON.parse(outstr)
	
	#for i in range(1000000):
	#	var buffer = sproto.encode("auth.Player", player)
	#	var result = sproto.decode("auth.Player", buffer)
		#print(result)
	
	var enddt = OS.get_unix_time()
	var interval = enddt - unixdt
	print(interval)
	pass # replace with function body
