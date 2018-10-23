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

const SIZEOF_INT64 = 8
const SIZEOF_INT32 = 4

var sp = null

class Buffer:
	var buffer = []
	var index = 0
	func init(arr):
		buffer = Array(arr)
	func move(size):
		index = index + size
		return self
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
		if index + idx + sz > buffer.size():
			sz = buffer.size() - index - idx
		result.resize(sz+1)
		for i in range(sz):
			result[i] = buffer[index+idx+i]
		return result
	func get_string_from_utf8(idx, sz):
		return PoolByteArray(slice(idx, sz)).get_string_from_utf8()
	func splice(idx, sz):
		if sz == 0:
			return
		var begin = idx + index
		if begin > buffer.size():
			return
		if sz > buffer.size() - begin:
			sz = buffer.size() - begin
		for i in range(sz):
			buffer.remove(index+idx)
		return sz
	
func expand_buffer(buffer, osz, nsz):
	while osz < nsz:
		osz *= 2
	if osz > ENCODE_MAXSIZE:
		return null
	buffer.buffer.resize(osz)
	return buffer

func expand64(v):
	var value = v
	if (value & 0x80000000) != 0:
		value = value | (~0) << 32
	return value

func toword(buffer):
	return buffer.get(0) | (buffer.get(1) << 8)

func todword(buffer):
	return buffer.get(0) | (buffer.get(1) << 8) | (buffer.get(2) << 16) | (buffer.get(3) << 24)

func count_array(buffer):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var length = todword(stream)
	var n = 0
	stream.move(SIZEOF_LENGTH)
	while length > 0:
		if length < SIZEOF_LENGTH : 
			return -1
		var nsz = todword(stream)
		nsz += SIZEOF_LENGTH
		if nsz > length:
			return -1
		n += 1
		stream.move(nsz)
		length -= nsz
	return n
	
	
func struct_field(buffer, sz):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var field = Buffer.new()
	if sz < SIZEOF_LENGTH:
		return -1
	var fn = toword(stream)
	var header = SIZEOF_HEADER + SIZEOF_FIELD * fn
	if sz < header:
		return -1
	field.pointer(stream, SIZEOF_HEADER)
	sz -= header
	stream.move(header)
	for i in range(fn):
		var pTmp = Buffer.new()
		pTmp.pointer(field, i * SIZEOF_FIELD)
		var value = toword(pTmp)
		if value != 0:
			continue
		if sz < SIZEOF_LENGTH:
			return -1
		var dsz = todword(stream)
		if sz < SIZEOF_LENGTH + dsz:
			return -1
		stream.move(SIZEOF_LENGTH + dsz)
		sz -= SIZEOF_LENGTH + dsz
	
	return fn

func import_string(s, buffer):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var sz = todword(stream)
	return stream.get_string_from_utf8(SIZEOF_LENGTH, sz)

func calc_pow(base, n):
	if n == 0:
		return 1
	var r = int(calc_pow(base * base, floor( n / 2)))
	if (int(n) & 1) != 0 :
		r *= int(base)
	return r
	
func import_field(s, f, buffer):
	var stream = Buffer.new()
	stream.pointer(buffer)
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
		var pTmp = Buffer.new()
		pTmp.pointer(stream, SIZEOF_FIELD * i)
		var value = toword(pTmp)
		if value & 1 != 0:
			tag += floor(value / 2)
			continue
		if tag == 0:
			if value != 0:
				return null
			pTmp.pointer(stream, fn * SIZEOF_FIELD)
			f.name = import_string(s, pTmp)
			continue
		if value == 0:
			return null
		value = floor(value/2) - 1
		if tag == 1:
			if value >= SPROTO_TSTRUCT:
				return null
			f.type = value
		elif tag == 2:
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
		elif tag == 3:
			f.tag = value
		elif tag == 4:
			if value != 0:
				array = SPROTO_TARRAY
		elif tag == 5:
			f.key = value
		else:
			return null
		
	if f.tag < 0 || f.type < 0 || f.name == null:
		return null
	f.type = int(f.type) | array
	return result
	
func import_type(s, t, buffer):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var result = Buffer.new()
	var sz = todword(stream)
	var fn
	var n
	var maxn
	var last
	stream.move(SIZEOF_LENGTH)
	result.pointer(stream, sz)
	fn = struct_field(stream, sz)
	if fn <= 0 || fn > 2:
		return null
	for i in range(0, fn*SIZEOF_FIELD, SIZEOF_FIELD):
		var pTmp = Buffer.new()
		pTmp.pointer(stream, SIZEOF_HEADER + i)
		var v = toword(pTmp)
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
	t.f = Array()
	t.f.resize(n)
	for i in range(n):
		t.f[i] = {}
		var f = t.f[i]
		stream = import_field(s, f, stream)
		if stream == null:
			return null
		var tag = f.tag
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
	
func import_protocol(s, p, buffer):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var result = Buffer.new()
	var sz = todword(stream)
	stream.move(SIZEOF_LENGTH)
	result.pointer(stream, sz)
	var fn = struct_field(stream, sz)
	stream.move(SIZEOF_HEADER)
	p.name = null
	p.tag = -1
	p.p = Array()
	p.p.resize(2)
	p.p[SPROTO_REQUEST] = null
	p.p[SPROTO_RESPONSE] = null
	p.confirm = 0
	var tag = 0
	for i in range(fn):
		tag += 1
		var pTmp = Buffer.new()
		pTmp.pointer(stream, SIZEOF_FIELD * i)
		var value = toword(pTmp)
		if (value & 1) > 0:
			tag += floor((value-1)/2)
			continue
		value = floor(value/2) - 1
		if i == 0:
			if value != -1:
				return null
			pTmp.pointer(stream, SIZEOF_FIELD *fn)
			p.name = import_string(s, pTmp)
		elif i == 1:
			if value < 0:
				return null
			p.tag = value
		elif i == 2:
			if value < 0 || value >= s.type_n:
				return null
			p.p[SPROTO_REQUEST] = s.type[value]
		elif i == 3:
			if value < 0 || value > s.type_n:
				return null
			p.p[SPROTO_RESPONSE] = s.type[value]
		elif i == 4:
			p.confirm = value
		else:
			return null
	if p.name == null || p.tag < 0:
		return null
	return result
	
	
func create_from_bundle(s, buffer, sz):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var content = Buffer.new()
	var typedata = Buffer.new()
	var protocoldata = Buffer.new()
	var fn = struct_field(stream, sz)
	if fn < 0 || fn > 2:
		return null
	stream.move(SIZEOF_HEADER)
	content.pointer(stream, fn*SIZEOF_FIELD)
	for i in range(fn):
		var pTmp = Buffer.new()
		pTmp.pointer(stream, i*SIZEOF_FIELD)
		var value = toword(pTmp)
		if value != 0:
			return null
		var n = count_array(content)
		if n < 0:
			return null
		if i == 0:
			typedata.pointer(content, SIZEOF_LENGTH)
			s.type_n = n
			s.type = Array()
			s.type.resize(n)
		else:
			protocoldata.pointer(content, SIZEOF_LENGTH)
			s.protocol_n = n
			s.proto = Array()
			s.proto.resize(n)
		content.move(todword(content) + SIZEOF_LENGTH)
	for i in range(s.type_n):
		s.type[i] = {}
		typedata = import_type(s, s.type[i], typedata)
		if typedata == null:
			return null
	for i in range(s.protocol_n):
		s.proto[i] = {}
		protocoldata = import_protocol(s, s.proto[i], protocoldata)
		if protocoldata == null:
			return null
	
	return s

#根据协议名查tag序号
func sproto_prototag(name):
	if sp == null:
		return -1
	for i in range(sp.protocol_n):
		if name == sp.proto[i].name:
			return sp.proto[i].tag
	return -1
	
#根据tag序号查proto
func query_proto(tag):
	if sp == null:
		return null
	var begin = 0
	var end = sp.protocol_n
	while begin < end:
		var mid = floor((begin + end) / 2)
		if sp.proto[mid].tag == tag:
			return sp.proto[mid]
		if tag > sp.proto[mid].tag:
			begin = mid + 1
		else:
			end = mid
	return null

#根据协议查找协议类型
func sproto_protoquery(name, what):
	if what < 0 || what > 1:
		return null
	var tag = sproto_prototag(name)
	if tag == -1:
		return null
	
	var p = query_proto(tag)
	if p != null:
		return p.p[what]
	return null
	
func sproto_protoname(tag):
	var p = query_proto(tag)
	if p != null:
		return p.name
	return null

func sproto_type(name):
	for i in range(sp.type_n):
		if name == sp.type[i].name:
			return sp.type[i]
	return null

func findtag(st, tag):
	var begin
	var end
	if st.base >= 0:
		tag -= st.base
		if tag < 0 || tag > st.n:
			return null
		return st.f[tag]
	
	begin = 0
	end = st.n
	while begin < end:
		var mid = floor((begin+end)/2)
		if st.f[mid].tag == tag:
			return st.f[mid]
		if tag > st.f[mid].tag:
			begin = mid + 1
		else:
			end = mid
	return null
	
func fill_size(buffer, sz):
	buffer.set(0, sz & 0xff)
	buffer.set(1, (sz >> 8) & 0xff)
	buffer.set(2, (sz >> 16) & 0xff)
	buffer.set(3, (sz >> 24) & 0xff)
	return sz + SIZEOF_LENGTH
	
func encode_integer(v, buffer):
	if buffer.size() - buffer.index < SIZEOF_LENGTH + SIZEOF_INT32:
		return -1
	buffer.set(4, v & 0xff)
	buffer.set(5, (v >> 8) & 0xff)
	buffer.set(6, (v >> 16) & 0xff)
	buffer.set(7, (v >> 24) & 0xff)
	return fill_size(buffer, 4)
	
func encode_uint64(v, buffer):
	if buffer.size() - buffer.index < SIZEOF_LENGTH + SIZEOF_INT64:
		return -1
	buffer.set(4, v & 0xff)
	buffer.set(5, (v >> 8) & 0xff)
	buffer.set(6, (v >> 16) & 0xff)
	buffer.set(7, (v >> 24) & 0xff)
	buffer.set(8, (v >> 32) & 0xff)
	buffer.set(9, (v >> 40) & 0xff)
	buffer.set(10, (v >> 48) & 0xff)
	buffer.set(11, (v >> 56) & 0xff)
	return fill_size(buffer, 8)
	
func encode_object(cb, args, buffer):
	var size = buffer.size() - buffer.index
	if size < SIZEOF_LENGTH:
		return -1
	args.buffer = Buffer.new()
	args.buffer.pointer(buffer, SIZEOF_LENGTH)
	args.length = size - SIZEOF_LENGTH
	var sz = cb.call_func(args)
	if sz < 0:
		if sz == SPROTO_CB_NIL:
			return 0
		return -1
	return fill_size(buffer, sz)
	
func uint32_to_uint64(negative, buffer):
	if negative:
		buffer.set(4, 0xff)
		buffer.set(5, 0xff)
		buffer.set(6, 0xff)
		buffer.set(7, 0xff)
	else:
		buffer.set(4, 0)
		buffer.set(5, 0)
		buffer.set(6, 0)
		buffer.set(7, 0)
		
func encode_integer_array(cb, args, buffer, size, noarray):
	var stream = Buffer.new()
	stream.pointer(buffer)
	
	var header = Buffer.new()
	header.pointer(stream)
	if size < 1:
		return null
	stream.move(1)
	size -= 1
	var intlen = SIZEOF_INT32
	var index = 1
	noarray.value = 0
	
	while true:
		args.value = null
		args.length = 8
		args.index = index
		var sz = cb.call_func(args)
		if sz <= 0:
			if sz == SPROTO_CB_NIL:
				break
			if sz == SPROTO_CB_NOARRAY:
				noarray.value = 1
				break
			return null
		if size < SIZEOF_INT64:
			return null
		if sz == SIZEOF_INT32:
			var v = args.value
			stream.set(0, v & 0xff)
			stream.set(1, (v >> 8) & 0xff)
			stream.set(2, (v >> 16) & 0xff)
			stream.set(3, (v >> 24) & 0xff)
			if intlen == SIZEOF_INT64:
				uint32_to_uint64(v & 0x80000000, stream)
		else:
			if sz != SIZEOF_INT64:
				return null
			if intlen == SIZEOF_INT32:
				size -= (index - 1) * SIZEOF_INT32
				if size < SIZEOF_INT64:
					return null
				stream.move((index-1) * SIZEOF_INT32)
				for i in range(index-2,-1,-1):
					var negative
					for j in range((1 + i * SIZEOF_INT64), (1 + i * SIZEOF_INT64 + SIZEOF_INT32), 1):
						header.set(j, header.get(j - SIZEOF_INT32 * i))
					negative = header.get(SIZEOF_INT64 * i + SIZEOF_INT32) & 0x80
					var pTmp = Buffer.new()
					pTmp.pointer(header, 1 + i * SIZEOF_INT64)
					uint32_to_uint64(negative, pTmp)
				intlen = SIZEOF_INT64
			
			var v = args.value
			stream.set(0, v & 0xff)
			stream.set(1, (v >> 8) & 0xff)
			stream.set(2, (v >> 16) & 0xff)
			stream.set(3, (v >> 24) & 0xff)
			stream.set(4, (v >> 32) & 0xff)
			stream.set(5, (v >> 40) & 0xff)
			stream.set(6, (v >> 48) & 0xff)
			stream.set(7, (v >> 56) & 0xff)
			
		size -= intlen
		stream.move(intlen)
		index += 1
	
	if stream.index == header.index + 1:
		return header
	header.set(0, intlen)
	return stream
	
func encode_array(cb, args, buffer):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var size = buffer.size() - buffer.index
	
	var data = Buffer.new()
	data.pointer(stream)
	
	if size < SIZEOF_LENGTH:
		return -1
	size -= SIZEOF_LENGTH
	stream.pointer(data, SIZEOF_LENGTH)
	if args.type == SPROTO_TINTEGER:
		var noarray = {}
		stream = encode_integer_array(cb, args, stream, size, noarray)
		if stream == null:
			return -1
		if noarray.value != 0:
			return 0
	elif args.type == SPROTO_TBOOLEAN:
		args.index = 1
		while true:
			args.value = 0
			args.length = 4
			var sz = cb.call_func(args)
			if sz < 0:
				if sz == SPROTO_CB_NIL:
					break
				if sz == SPROTO_CB_NOARRAY:
					return 0
				return -1
			if size < 1:
				return -1
			if args.value == 1:
				stream.set(0, 1)
			else:
				stream.set(0, 0)
			size -= 1
			stream.move(1)
			args.index += 1
	else:
		args.index = 1
		while true:
			if size < SIZEOF_LENGTH:
				return -1
			size -= SIZEOF_LENGTH
			args.buffer = Buffer.new()
			args.buffer.pointer(stream, SIZEOF_LENGTH)
			args.length = size
			var sz = cb.call_func(args)
			if sz < 0:
				if sz == SPROTO_CB_NIL:
					break
				if sz == SPROTO_CB_NOARRAY:
					return 0
				return -1
			fill_size(stream, sz)
			stream.move(SIZEOF_LENGTH + sz)
			size -= sz
			args.index += 1
			
	var sz = stream.index - (data.index + SIZEOF_LENGTH)
	if sz == 0:
		return 0
	return fill_size(data, sz)
	
	
func sproto_encode(st, buffer, size, cb, ud):
	var args = {}
	var stream = Buffer.new()
	stream.pointer(buffer)
	
	var header = Buffer.new()
	header.pointer(stream)
	var data = Buffer.new()
	var header_sz = SIZEOF_HEADER + st.maxn * SIZEOF_FIELD
	var datasz
	if size < header_sz:
		return -1
	
	args.ud = ud
	data.pointer(header, header_sz)
	size -= header_sz
	var index = 0
	var lasttag = -1
	
	for i in range(st.n):
		var f = st.f[i]
		var type = f.type
		var value = 0
		var sz = -1
		args.tagname = f.name
		args.tagid = f.tag
		if f.st != null:
			args.subtype = sp.type[f.st]
		else:
			args.subtype = f.st
		args.mainindex = f.key
		args.extra = f.extra
		if (type & SPROTO_TARRAY) != 0:
			args.type = type & ~SPROTO_TARRAY
			sz = encode_array(cb, args, data)
		else:
			args.type = type
			args.index = 0
			if type == SPROTO_TINTEGER || type == SPROTO_TBOOLEAN:
				args.value = 0
				args.length = 8
				args.buffer = Buffer.new()
				args.buffer.pointer(stream)
				sz = cb.call_func(args)
				if sz < 0:
					if sz == SPROTO_CB_NIL:
						continue
					if sz == SPROTO_CB_NOARRAY:
						return 0
					return -1
				if sz == SIZEOF_INT32:
					if args.value < 0x7fff:
						value = (args.value + 1) * 2
						sz = 2
					else:
						sz = encode_integer(args.value, data)
				elif sz == SIZEOF_INT64:
					sz = encode_uint64(args.value, data)
				else:
					return -1
			elif type == SPROTO_TSTRUCT || type == SPROTO_TSTRING:
				sz = encode_object(cb, args, data)
		if sz < 0:
			return -1
		if sz > 0:
			var record = Buffer.new()
			if value == 0:
				data.move(sz)
				size -= sz
			record.pointer(header, SIZEOF_HEADER+SIZEOF_FIELD*index)
			var tag = f.tag - lasttag - 1
			if tag > 0:
				tag = (tag - 1) * 2 + 1
				if tag > 0xffff:
					return -1
				record.set(0, int(tag) & 0xff)
				record.set(1, (int(tag) >> 8) & 0xff)
				index += 1
				record.move(SIZEOF_FIELD)
			index += 1
			record.set(0, value & 0xff)
			record.set(1, (value >> 8) & 0xff)
			lasttag = f.tag
		continue	
	
	header.set(0, index & 0xff)
	header.set(1, (index >> 8) & 0xff)
	datasz = data.index - (header.index + header_sz)
	data.pointer(header, header_sz)
	if index != st.maxn:
		var v = data.slice(0, datasz)
		for i in range(datasz):
			header.set(SIZEOF_HEADER + index * SIZEOF_FIELD + i, v[i])
		header.splice(SIZEOF_HEADER + index * SIZEOF_FIELD + datasz, header.size())
			
	return SIZEOF_HEADER + index * SIZEOF_FIELD + datasz
	
func _encode(args):
	var sel = args.ud
	if sel.deep >= ENCODE_DEEPLEVEL:
		return -1
	if not sel.indata.has(args.tagname):
		return SPROTO_CB_NIL
	var target = null
	if args.index > 0:
		if args.tagname != sel.array_tag:
			sel.array_tag = args.tagname
			if typeof(sel.indata[args.tagname]) != TYPE_DICTIONARY && typeof(sel.indata[args.tagname]) != TYPE_ARRAY:
				sel.array_index = 0
				return SPROTO_CB_NIL
			if not sel.indata.has(args.tagname):
				sel.array_index = 0
				return SPROTO_CB_NOARRAY
		if sel.indata[args.tagname].size() < args.index:
			return SPROTO_CB_NIL
		target = sel.indata[args.tagname][args.index-1]
		if target == null:
			return SPROTO_CB_NIL
	else:
		target = sel.indata[args.tagname]
		
	if args.type == SPROTO_TINTEGER:
		var v
		var vh
		if args.extra > 0:
			var vn = target
			v = floor(vn * args.extra + 0.5)
		else:
			v = target
		vh = v >> 31
		if vh == 0 || vh == -1: 
			args.value = v
			return 4
		else:
			args.value = v
			return 8
	elif args.type == SPROTO_TBOOLEAN:
		if target == true:
			args.value = 1
		elif target == false:
			args.value = 0
		return 4
	elif args.type == SPROTO_TSTRING:
		var arr = target.to_utf8()
		args.length = arr.size()
		if args.buffer.size() - args.buffer.index < arr.size():
			return SPROTO_CB_ERROR
		for i in range(arr.size()):
			args.buffer.set(i, arr[i])
		return args.length
	elif args.type == SPROTO_TSTRUCT:
		var sub = {}
		sub.st = args.subtype
		sub.deep = sel.deep + 1
		sub.indata = target
		var r = sproto_encode(args.subtype, args.buffer, args.length, funcref(self, "_encode"), sub)
		if r < 0:
			return SPROTO_CB_ERROR
		return r
	else:
		print("error!")
				
		
func decode_array_object(cb, args, buffer, sz):
	var hsz
	var index = 1
	var stream = Buffer.new()
	stream.pointer(buffer)
	while sz > 0:
		if sz < SIZEOF_LENGTH:
			return -1
		hsz = todword(stream)
		stream.move(SIZEOF_LENGTH)
		sz -= SIZEOF_LENGTH
		if hsz > sz:
			return -1
		args.index = index
		args.value = Buffer.new()
		args.value.pointer(stream)
		args.length = hsz
		var ret = cb.call_func(args)
		if ret != 0:
			return -1
		sz -= hsz
		stream.move(hsz)
		index += 1
	return 0
	
func decode_array(cb, args, buffer):
	var stream = Buffer.new()
	stream.pointer(buffer)
	var sz = todword(stream)
	var type = args.type
	if sz == 0:
		args.index = -1
		args.value = null
		args.length = 0
		cb.call_func(args)
		return 0
	stream.move(SIZEOF_LENGTH)
	if type == SPROTO_TINTEGER:
		var length = stream.get(0)
		stream.move(1)
		sz -= 1
		if length == 4:
			if sz % 4 != 0:
				return -1
			for i in range(floor(sz/4)):
				var pTmp = Buffer.new()
				pTmp.pointer(stream, i*SIZEOF_INT32)
				var value = expand64(todword(pTmp))
				args.index = i + 1
				args.value = value
				args.length = 8
				cb.call_func(args)
		elif length == 8:
			if sz % 8 != 0:
				return -1
			for i in range(floor(sz/8)):
				var pTmp = Buffer.new()
				pTmp.pointer(stream, i*8)
				var low = todword(pTmp)
				pTmp.pointer(stream, i*8 + 4)
				var hi = todword(pTmp)
				var value = low | (hi << 32)
				args.index = i + 1
				args.value = value
				args.length = 8
				cb(args)
		else:
			return -1
	elif type == SPROTO_TBOOLEAN:
		for i in range(sz):
			var value = stream.get(i)
			args.index = i + 1
			args.value = value
			args.length = 8
			cb.call_func(args)
	elif type == SPROTO_TSTRING || type == SPROTO_TSTRUCT:
		return decode_array_object(cb, args, stream, sz)
	else:
		return -1
	return 0

func sproto_decode(st, buffer, cb, ud):
	var size = buffer.size() - buffer.index
	if size < SIZEOF_HEADER:
		return -1
	var args = {}
	var total = size
	var data = Buffer.new()
	data.pointer(buffer)
	var stream = Buffer.new()
	stream.pointer(data)
	var datastream = Buffer.new()
	var fn = toword(stream)
	stream.move(SIZEOF_HEADER)
	size -= SIZEOF_HEADER
	if size < fn * SIZEOF_FIELD:
		return -1
	datastream.pointer(stream, fn * SIZEOF_FIELD)
	size -= fn * SIZEOF_FIELD
	args.ud = ud
	var tag = -1
	for i in range(fn):
		var f = null
		var pTmp = Buffer.new()
		pTmp.pointer(stream, i * SIZEOF_FIELD)
		var value = toword(pTmp)
		tag += 1
		if value & 1 != 0:
			tag += floor(value / 2)
			continue
		value = floor(value/2) - 1
		var currentdata = Buffer.new()
		currentdata.pointer(datastream)
		if value < 0:
			var sz
			if size < SIZEOF_LENGTH:
				return -1
			sz = todword(datastream)
			if size < sz + SIZEOF_LENGTH:
				return -1
			datastream.move(sz + SIZEOF_LENGTH)
			size -= sz + SIZEOF_LENGTH
		f = findtag(st, tag)
		if f == null:
			continue
		args.tagname = f.name
		args.tagid = f.tag
		args.type = f.type & (~SPROTO_TARRAY)
		if f.st != null:
			args.subtype = sp.type[f.st]
		else:
			args.subtype = null
		args.index = 0
		args.mainindex = f.key
		args.extra = f.extra
		if value < 0:
			if (f.type & SPROTO_TARRAY) != 0:
				if decode_array(cb, args, currentdata):
					return -1
			else:
				if f.type == SPROTO_TINTEGER:
					var sz = todword(currentdata)
					if sz == 4:
						pTmp.pointer(currentdata, SIZEOF_LENGTH)
						var v = expand64(todword(pTmp))
						args.value = v
						args.length = 8
						cb.call_func(args)
					elif sz != 8:
						return -1
					else:
						pTmp.pointer(currentdata, SIZEOF_LENGTH)
						var low = todword(pTmp)
						pTmp.pointer(currentdata, SIZEOF_LENGTH + SIZEOF_INT32)
						var hi = todword(pTmp)
						var v = low | (hi << 32)
						args.value = v
						args.length = 8
						cb.call_func(args)
				elif f.type == SPROTO_TSTRING || f.type == SPROTO_TSTRUCT:
					var sz = todword(currentdata)
					args.value = Buffer.new()
					args.value.pointer(currentdata, SIZEOF_LENGTH)
					args.length = sz
					if cb.call_func(args) != 0:
						return -1
				else:
					return -1
		elif f.type != SPROTO_TINTEGER && f.type != SPROTO_TBOOLEAN:
			return -1
		else:
			args.value = value
			args.length = 8
			cb.call_func(args)
	return total - size
	
func _decode(args):
	var sel = args.ud
	var value
	if sel.deep > ENCODE_DEEPLEVEL:
		print("the table is too deep")
	if args.index != 0:
		if args.tagname != sel.array_tag:
			sel.array_tag = args.tagname
			if args.mainindex >= 0:
				sel.result[args.tagname] = {}
			else:
				sel.result[args.tagname] = Array()
			if args.index < 0:
				return 0
					
	if args.type == SPROTO_TINTEGER:
		if args.extra != 0:
			value = args.value / args.extra
		else:
			value = args.value
	elif args.type == SPROTO_TBOOLEAN:
		if args.value == 1:
			value = true
		elif args.value == 0:
			value = false
		else:
			value = null
	elif args.type == SPROTO_TSTRING:
		value = args.value.get_string_from_utf8(0, args.length)
	elif args.type == SPROTO_TSTRUCT:
		var sub = {}
		sub.deep = sel.deep + 1
		sub.array_index = 0
		sub.array_tag = null
		sub.result = {}
		if args.mainindex >= 0:
			sub.mainindex_tag = args.mainindex
			var r = sproto_decode(args.subtype, args.value, funcref(self, "_decode"), sub)
			if r < 0 || r != args.length:
				return r
			value = sub.result
		else:
			sub.mainindex_tag = -1
			sub.key_index = 0
			var r = sproto_decode(args.subtype, args.value, funcref(self, "_decode"), sub)
			if r < 0:
				return SPROTO_CB_ERROR
			if r != args.length:
				return r
			value = sub.result
	else:
		print("Invalid Type")
		
	if args.index > 0:
		if args.mainindex >= 0:
			var _mainindex = value["_mainindex"]
			value.erase("_mainindex")
			sel.result[args.tagname][_mainindex] = value
		else:
			sel.result[args.tagname].push_back(value)
	else:
		if sel.mainindex_tag == args.tagid:
			sel.result["_mainindex"] = value
		sel.result[args.tagname] = value
		
	return 0
			
func querytype(typename):
	if sp.tcache.has(typename) == false:
		var v = sproto_type(typename)
		sp.tcache[typename] = v
		return v
	else:
		return sp.tcache[typename]

func pack(buffer):
	pass
	
func unpack(buffer):
	pass
	
func encode(type, data):
	var sel = {}
	var st = null
	if typeof(type) == TYPE_STRING || typeof(type) == TYPE_INT:
		st = querytype(type)
	else:
		st = type
	var tbl_index = 2
	var buffer = Buffer.new()
	var tmp = Array()
	tmp.resize(128)
	buffer.init(tmp)
	var sz = buffer.size()
	sel.st = st
	sel.tbl_index = tbl_index
	sel.indata = data
	
	while true:
		sel.array_tag = null
		sel.array_index = 0
		sel.deep = 0
		sel.iter_index = tbl_index + 1
		var r = sproto_encode(st, buffer, sz, funcref(self, "_encode"), sel)
		if r < 0:
			buffer = expand_buffer(buffer, sz, sz * 2)
			sz *= 2
		else:
			if buffer.size() > r:
				buffer.splice(r, buffer.size()-r)
			return buffer
	
func decode(type, buffer):
	var st = null
	if typeof(type) == TYPE_STRING || typeof(type) == TYPE_INT:
		st = querytype(type)
	else:
		st = type
	var stream = Buffer.new()
	stream.pointer(buffer)
	var sz = stream.size()
	var ud = {}
	ud.array_tag = null
	ud.deep = 0
	ud.result = {}
	var r = sproto_decode(st, stream, funcref(self, "_decode"), ud)
	if r < 0:
		return null
	return ud.result
	
	
func pencode(type, buffer):
	pass
	
func pdecode(type, buffer):
	pass
	
##使用sproto生成的spb文件初始化
func create_from_spb(filepath):
	var file = File.new()
	if file.open(filepath, File.READ) == OK:
		var fileBytes = file.get_buffer(file.get_len())
		var fileArr = Array(fileBytes)
		var buffer = Buffer.new()
		buffer.init(fileArr)
		var s = {}
		s.type_n = 0
		s.protocol_n = 0
		s.type = null
		s.proto = null
		s.tcache = {}
		s.pcache = {}
		sp = create_from_bundle(s, buffer, buffer.size())
		if sp == null:
			return null
