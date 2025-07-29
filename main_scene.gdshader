shader_type sky;

void sky() {
	// Called for every visible pixel in the sky background, as well as all pixels
	// in the radiance cubemap.
    if(AT_CUBEMAP_PASS){
        COLOR = vec3(0.1, 0.1, 0.1);
    }else{
        COLOR = vec3(0.2, 0.6, 1.0);
    }
}
