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
	#var buf = Buffer.new()
	#buf.init([0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x77, 0x6F, 0x72, 0x6C, 0x64, 0x00])
	#var buf1 = Buffer.new()
	#buf1.pointer(buf)
	#test2(buf)
	#print(buf.buffer)
	#print(buf.index)

	
	#buf1.move(1)
	#buf1.set(128)
	#print(buf.buffer)
	#print(buf.index)
	
	#var bytes = buf.slice(0,13)
	#var bytesArr = PoolByteArray(bytes)
	#var ss = bytesArr.get_string_from_utf8()
	#print(ss)
	#print(buf.get_string_from_utf8(0, 5))
	
	for i in range(3,0,-1):
		print(i)
	
	var sproto = Sproto.new()
	
	sproto.create_from_spb("res://protocol.spb")
	
	pass # replace with function body
