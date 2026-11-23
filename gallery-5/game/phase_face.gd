extends Control
## Three linked views of one measured Z, velocity and magnetic-moment cell.
const FONT := preload("res://museum/fonts/DejaVuSans.ttf")
const SERIF := preload("res://museum/fonts/DejaVuSerif.ttf")
const PIXELS := Vector2i(1800, 564)
const BAND := Rect2(85,153,476,207)
const CUT := Rect2(680,153,430,207)
const TRACE := Rect2(1275,153,432,72)
const MINT := Color("#69f8c6")
const AMBER := Color("#fda36d")
const RULE := Color("#707070")
const SAMPLE_NAMES := ["Midplane","Inside the turn","Beam turn","Right throat","Right sheath"]
var data: Dictionary
var entry: Dictionary
var record: Dictionary
var atlas: Texture2D
var mu_index := 1
var slice_index := 0
var speed_index := 32

func _text(words: String, x: float, y: float, px: int, book := false) -> void:
	draw_string(SERIF if book else FONT, Vector2(x,y), words, HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color.WHITE)

func _center(words: String, x: float, y: float, px: int, width: float) -> void:
	draw_string(FONT,Vector2(x-width/2,y),words,HORIZONTAL_ALIGNMENT_CENTER,width,px,Color.WHITE)

func _tile(rect: Rect2, tile: int) -> void:
	var source := Rect2((tile % 3)*512, floori(tile/3.0)*256, 512, 256)
	draw_texture_rect_region(atlas,rect,source)
	draw_rect(rect, RULE, false, 1.5)

func _point(rect: Rect2, fx: float, fy: float) -> void:
	if fx<0 or fx>1 or fy<0 or fy>1:
		return
	var p := rect.position + rect.size * Vector2(fx,1-fy)
	draw_arc(p,8,0,TAU,24,Color.BLACK,5,true)
	draw_arc(p,8,0,TAU,24,Color.WHITE,2.4,true)

func _axis(rect: Rect2, ticks: Array, low: float, high: float, unit: String) -> void:
	for n: float in ticks:
		var px := remap(n,low,high,rect.position.x,rect.end.x)
		draw_line(Vector2(px,rect.end.y), Vector2(px,rect.end.y+6), Color.WHITE,2)
		_center(str(int(n)),px,rect.end.y+26,21,50)
	_center(unit,rect.get_center().x,rect.end.y+58,23,rect.size.x+100)

func _y_tick(rect: Rect2, label: String, fraction: float) -> void:
	var y := lerpf(rect.end.y, rect.position.y, fraction)
	draw_line(Vector2(rect.position.x-5,y),Vector2(rect.position.x,y),Color.WHITE,1.5)
	draw_string(FONT,Vector2(rect.position.x-58,y+6),label,HORIZONTAL_ALIGNMENT_RIGHT,49,20,Color.WHITE)

func _trace(rect: Rect2, values: Array, low: float, high: float, ink: Color) -> void:
	draw_rect(rect,RULE,false,1)
	var points := PackedVector2Array()
	for j in values.size():
		var left := maxf(-3,float(data.v_faces[j])*1e-6)
		var right := minf(3,float(data.v_faces[j+1])*1e-6)
		if left >= right:
			continue
		var y := remap(clampf(values[j],low,high),low,high,rect.end.y,rect.position.y)
		points.append(Vector2(remap(left,-3,3,rect.position.x,rect.end.x),y))
		points.append(Vector2(remap(right,-3,3,rect.position.x,rect.end.x),y))
	draw_polyline(points,ink,2.5,true)
	_y_tick(rect,String.num(high,1 if high<10 else 0),1)
	_y_tick(rect,"0",(-low)/(high-low))
	_point(rect,(float(data.v[speed_index])*1e-6+3)/6,clampf((float(values[speed_index])-low)/(high-low),0,1))

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,PIXELS),Color.BLACK)
	if record.is_empty():
		return
	var mu: float = data.mu[mu_index]
	var v: float = float(data.v[speed_index])*1e-6
	var z: float = record.z
	_text("Where do ions accumulate relative to where they enter?",42,52,43,true)
	_text("%s   ·   Rₘ = 32   ·   fᵢ shows where ions have accumulated (#75, 0.500150 s). Sᵢ shows where fuel enters (#0, 0 s)." % entry.run,43,91,25)
	draw_line(Vector2(40,108),Vector2(1758,108),RULE,2)
	_text("At fixed μ   ·   v∥ (10⁶ m/s)",BAND.position.x,141,25,true)
	_tile(BAND,mu_index)
	_axis(BAND,[-1,0,1],-1.05,1.05,"Axial position Z (m)")
	for n in [-2,0,2]:
		_y_tick(BAND,str(n),(float(n)+2.2)/4.4)
	_point(BAND,(z+1.05)/2.1,(v+2.2)/4.4)
	if absf(z)>1.05:
		_text("Selected Z is beyond this panel",BAND.position.x+14,BAND.position.y+27,21)
	_text("%s   ·   μ (keV/T), asinh scale" % SAMPLE_NAMES[slice_index],CUT.position.x,141,25,true)
	_tile(CUT,int(record.tile))
	_axis(CUT,[-3,0,3],-3,3,"Parallel velocity v∥ (10⁶ m/s)")
	for n in [0,1,10,70]:
		_y_tick(CUT,str(n),asinh(n)/asinh(70.99155))
	_point(CUT,(v+3)/6,asinh(mu)/asinh(70.99155))
	_text("Final ion distribution fᵢ (s³/m⁶)",TRACE.position.x,141,25,true)
	_trace(TRACE,record.f,-.005,1.6,AMBER)
	var lower := Rect2(TRACE.position+Vector2(0,135),TRACE.size)
	_text("Ion injection rate Sᵢ (s²/m⁶)",lower.position.x,lower.position.y-12,25,true)
	_trace(lower,record.s,0,200,MINT)
	_axis(lower,[-3,0,3],-3,3,"Parallel velocity v∥ (10⁶ m/s)")
	_text("Signed fᵢ (s³/m⁶)   ·   logarithmic magnitude",43,460,24)
	var tick_names := ["−10⁻³","−10⁻⁵","<10⁻⁶","10⁻⁵","10⁻³","10⁻¹","1"]
	for k in tick_names.size():
		var key := Rect2(655+float(k)*137,436,35,26)
		draw_rect(key,Color(data.heat_key[k]))
		draw_rect(key,RULE,false,1)
		_text(tick_names[k],key.end.x+6,key.end.y-3,22)
	_text("Podium surfaces enclose fᵢ above each marked value (s³/m⁶). Select a colour to isolate it. Green lines trace Sᵢ = 8 s²/m⁶.",43,493,24)
	_text("Probe    Z = %+.4f m     v∥ = %+.3f × 10⁶ m/s     μ = %.2f keV/T     fᵢ = %s s³/m⁶     Sᵢ = %s s²/m⁶" % [
		z,v,mu,number(record.f[speed_index]),number(record.s[speed_index])],43,542,28,true)

static func number(value: float) -> String:
	if value == 0:
		return "0"
	var exponent := floori(log(absf(value))/log(10))
	if exponent >= -2 and exponent < 4:
		return String.num(value,3)
	return "%.2f×10^%d" % [value/pow(10.0,exponent),exponent]
