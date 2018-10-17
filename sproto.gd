#常量定义
const SPROTO_REQUEST = 0
const SPROTO_RESPONSE = 1

const SPROTO_TINTEGER = 0
const SPROTO_TBOOLEAN = 1
const SPROTO_TSTRING = 2
const SPROTO_TSTRUCT = 3

const SPROTO_TSTRING_STRING = 0
const SPROTO_TSTRING_BINARY = 1

const SPROTO_CB_ERROR = -1
const SPROTO_CB_NIL = -2
const SPROTO_CB_NOARRAY = -3

const SPROTO_TARRAY = 0x80
const CHUNK_SIZE = 1000
const SIZEOF_LENGTH = 4
const SIZEOF_HEADER = 2
const SIZEOF_FIELD = 2

const ENCODE_BUFFERSIZE = 2050
const ENCODE_MAXSIZE = 0x1000000
const ENCODE_DEEPLEVEL = 64


class Buffer:
	var buffer = []
	var index = 0
	func init(arr):
		buffer = Array(arr)
	func move(size):
		index = index + size
	func size():
		return buffer.size()
	func get(idx):
		return buffer[index+idx]
	func set(idx, value):
		buffer[index+idx] = value
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
		return PoolByteArray(slice(idx, sz)).get_string_from_utf8()

func toword(buffer):
	return buffer.get(0) | buffer.get(1) << 8

func todword(buffer):
	return buffer.get(0) | buffer.get(1) << 8 | buffer.get(2) << 16 | buffer.get(3) << 24

func count_array(buffer):
	var length = todword(buffer)
	var n = 0
	buffer.move(SIZEOF_LENGTH)
	while length > 0:
		if length < SIZEOF_LENGTH : 
			return -1
		var nsz = todword(buffer)
		nsz += SIZEOF_LENGTH
		if nsz > length:
			return -1
		n += 1
		buffer.move(nsz)
		length -= nsz
	return n
	
	
func struct_field(buffer, sz):
	var field = Buffer.new()
	if sz < SIZEOF_LENGTH:
		return -1
	var fn = toword(buffer)
	var header = SIZEOF_HEADER + SIZEOF_FIELD * fn
	if sz < header:
		return -1
	field.pointer(buffer, SIZEOF_HEADER)
	sz -= header
	buffer.move(header)
	for i in range(fn):
		var value = toword(field.move(i * SIZEOF_FIELD))
		if value != 0:
			continue
		if sz < SIZEOF_LENGTH:
			return -1
		var dsz = todword(buffer)
		if sz < SIZEOF_LENGTH + dsz:
			return -1
		buffer.move(SIZEOF_LENGTH + dsz)
		sz -= SIZEOF_LENGTH + dsz
	
	return fn

func import_string(s, stream):
	var sz = todword(stream)
	return stream.get_string_from_utf8(SIZEOF_LENGTH, sz)

func calc_pow(base, n):
	if n == 0:
		return 1
	var r = calc_pow(base * base, floor( n / 2))
	if (n & 1) != 0 :
		r *= base
	return r	
	
func import_field(s, f, stream):
	var sz
	var result = Buffer.new()
	var fn
	var i
	var array = 0
	var tag = -1
	f.tag = -1
	f.type = -1
	f.name = null
	f.st = null
	f.key = -1
	f.extra = 0
	
	sz = todword(stream)
	stream.move(SIZEOF_LENGTH)
	result.pointer(stream, sz)
	fn = struct_field(stream, sz)
	if fn < 0:
		return null
	stream.move(SIZEOF_HEADER)
	for i in range(fn):
		tag += 1
		var p = Buffer.new()
		p.pointer(stream, SIZEOF_FIELD * i)
		var value = toword(p)
		if value & 1 != 0:
			tag += floor(valuie / 2)
			continue
		if tag == 0:
			if value != 0:
				return null
			p.pointer(stream, fn * SIZEOF_FIELD)
			f.name = import_string(s, p)
			continue
		if value == 0:
			return null
		value = floor(value/2) - 1
		match tag:
			1:
				if value >= SPROTO_TSTRUCT:
					return null
				f.type = value
			2:
				if f.type == SPROTO_TINTEGER:
					f.extra = calc_pow(10, value)
				elif f.type == SPROTO_TSTRING:
					f.extra = value
				else:
					if value >= s.type_n:
						return null
					if f.type >= 0:
						return null
					f.type = SPROTO_TSTRUCT
					f.st = value
			3:
				f.tag = value
			4:
				if value != 0:
					array = SPROTO_TARRAY
			5:
				f.key = value
			_:
				return null
		
	if f.tag < 0 || f.type < 0 || f.name == null:
		return null
	f.type |= array
	return result
	
func import_type(s, t, stream):
	var result = Buffer.new()
	var sz = todword(stream)
	var i
	var fn
	var n
	var maxn
	var last
	stream.move(SIZEOF_LENGTH)
	result.pointer(stream, sz)
	if fn <= 0 || fn > 2:
		return null
	for i in range(0, fn*SIZEOF_FIELD, SIZEOF_FIELD):
		var p = Buffer.new()
		p.pointer(stream, SIZEOF_HEADER + i)
		var v = toword(p)
		if v != 0:
			return null
	
	t.name = null
	t.n = 0
	t.base = 0
	t.maxn = 0
	t.f = null
	stream.move(SIZEOF_HEADER + fn * SIZEOF_FIELD)
	t.name = import_string(s, stream)
	if fn == 1:
		return result
	stream.move(todword(stream) + SIZEOF_LENGTH)
	n = count_array(stream)
	if n < 0:
		return null
	stream.move(SIZEOF_LENGTH)
	maxn = n
	last = -1
	t.n = n
	t.f = [].resize(n)
	for i in range(n):
		t.f[i] = {}
		var f = t.f[i]
		stream = import_field(s, f, stream)
		if stream == null:
			return null
		tag = f.tag
		if tag <= last:
			return null
		if tag > last  + 1:
			maxn += 1
		last = tag
	t.maxn = maxn
	t.base = t.f[0].tag
	n = t.f[n-1].tag - t.base + 1
	if n != t.n:
		t.base = -1
	return result
	
