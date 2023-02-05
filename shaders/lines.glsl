P_DEFAULT float hash(P_DEFAULT float n) {
	return fract((1.0 + cos(n)) * 415.92653);
}

P_COLOR vec4 FragmentKernel (P_UV vec2 texCoord ) {
	P_COLOR vec4 ret = texture2D(CoronaSampler0, texCoord);
	P_UV vec2 pos = texCoord.xy;
	pos.x *= 1.5;
	pos.y *= 3.0;

	P_UV vec2 center = vec2(0.75, 1.5);
	ret.rgb = vec3(1.0-distance(center, pos));
	ret.rgb *= max(abs(sin(pos.y * 150.0)), 0.7);
	ret.a = (0.8 - ret.r*0.8);
	

	return CoronaColorScale(ret);

}