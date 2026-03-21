


// shader
(async () => {
    const canvas = document.getElementById('c');
    const gl = canvas.getContext('webgl2');
    const fpsEl = document.getElementById('fps');
    const fpsAvgEl = document.getElementById('fpsAvg');
    const fpsHighEl = document.getElementById('fpsHigh');
    const fpsLowEl = document.getElementById('fpsLow');
    const fps1LowEl = document.getElementById('fps1Low');
    const resetStatsBtn = document.getElementById('resetStats');
    const resolutionSelect = document.getElementById('resolution');

    if (!gl) {
        console.error('WebGL2 is not supported in this browser.');
        return;
    }

    const vertSrc = `#version 300 es
in vec2 a_pos;
void main() {
  gl_Position = vec4(a_pos, 0.0, 1.0);
}`;

    let fragSrc = await fetch('hallway.glsl').then(r => r.text());

    // Strip existing version and GL_ES precision block
    fragSrc = fragSrc.replace(/^\s*#version\s+\S+[^\n]*\n/, '');
    fragSrc = fragSrc.replace(/#ifdef GL_ES[\s\S]*?#endif/m, '');
    fragSrc = fragSrc.replace(/gl_FragColor/g, 'fragColor');

    fragSrc = `#version 300 es
precision highp float;
out vec4 fragColor;
` + fragSrc;

    function compile(type, src) {
        const s = gl.createShader(type);
        gl.shaderSource(s, src);
        gl.compileShader(s);
        if (!gl.getShaderParameter(s, gl.COMPILE_STATUS))
            console.error(gl.getShaderInfoLog(s));
        return s;
    }

    const prog = gl.createProgram();
    gl.attachShader(prog, compile(gl.VERTEX_SHADER, vertSrc));
    gl.attachShader(prog, compile(gl.FRAGMENT_SHADER, fragSrc));
    gl.linkProgram(prog);
    gl.useProgram(prog);

    const vao = gl.createVertexArray();
    gl.bindVertexArray(vao);
    const buf = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buf);
    gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
        -1,-1,  1,-1,  -1,1,
        1,-1,  1, 1,  -1,1
    ]), gl.STATIC_DRAW);
    const loc = gl.getAttribLocation(prog, 'a_pos');
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);

    const uRes = gl.getUniformLocation(prog, 'u_resolution');
    const uTime = gl.getUniformLocation(prog, 'u_time');

    function getRenderSize() {
        const mode = resolutionSelect ? resolutionSelect.value : 'native';

        if (mode === 'native') {
            return {
                width: Math.max(1, Math.floor(window.innerWidth)),
                height: Math.max(1, Math.floor(window.innerHeight))
            };
        }

        const [w, h] = mode.split('x').map(Number);
        return {
            width: Number.isFinite(w) ? Math.max(1, Math.floor(w)) : 1,
            height: Number.isFinite(h) ? Math.max(1, Math.floor(h)) : 1
        };
    }

    function resizeCanvas() {
        const { width, height } = getRenderSize();
        if (canvas.width !== width || canvas.height !== height) {
            canvas.width = width;
            canvas.height = height;
        }
        gl.viewport(0, 0, canvas.width, canvas.height);
    }

    window.addEventListener('resize', resizeCanvas);
    if (resolutionSelect) {
        resolutionSelect.addEventListener('change', () => {
            resizeCanvas();
            resetStats();
        });
    }

    // FPS tracking
    let frameTimes = [];
    let lastFrameTime = 0;
    let fpsLastUpdateTime = 0;

    function resetStats() {
        frameTimes = [];
        lastFrameTime = 0;
        fpsLastUpdateTime = 0;
        if (fpsEl) fpsEl.textContent = '--';
        if (fpsAvgEl) fpsAvgEl.textContent = '--';
        if (fpsHighEl) fpsHighEl.textContent = '--';
        if (fpsLowEl) fpsLowEl.textContent = '--';
        if (fps1LowEl) fps1LowEl.textContent = '--';
    }

    function updateStatsDisplay() {
        if (frameTimes.length === 0) return;

        const fpsValues = frameTimes.map(dt => (dt > 0 ? 1000 / dt : 0));
        const sortedFps = [...fpsValues].sort((a, b) => a - b);

        const current = fpsValues[fpsValues.length - 1];
        const avg = fpsValues.reduce((a, b) => a + b, 0) / fpsValues.length;
        const high = Math.max(...fpsValues);
        const low = Math.min(...fpsValues);
        const idx1Percent = Math.max(0, Math.floor(sortedFps.length * 0.01));
        const low1Percent = sortedFps[idx1Percent];

        if (fpsEl) fpsEl.textContent = current.toFixed(1);
        if (fpsAvgEl) fpsAvgEl.textContent = avg.toFixed(1);
        if (fpsHighEl) fpsHighEl.textContent = high.toFixed(1);
        if (fpsLowEl) fpsLowEl.textContent = low.toFixed(1);
        if (fps1LowEl) fps1LowEl.textContent = low1Percent.toFixed(1);
    }

    if (resetStatsBtn) {
        resetStatsBtn.addEventListener('click', resetStats);
    }

    function frame(t) {
        resizeCanvas();

        if (uRes) gl.uniform2f(uRes, canvas.width, canvas.height);
        if (uTime) gl.uniform1f(uTime, t * 0.001);
        gl.drawArrays(gl.TRIANGLES, 0, 6);

        // Track frame time
        if (lastFrameTime > 0) {
            const deltaTime = t - lastFrameTime;
            frameTimes.push(deltaTime);
            // Keep last 300 frames
            if (frameTimes.length > 300) {
                frameTimes.shift();
            }
        }
        lastFrameTime = t;

        // Stats update
        if (fpsLastUpdateTime === 0) fpsLastUpdateTime = t;
        if (t - fpsLastUpdateTime >= 500) {
            updateStatsDisplay();
            fpsLastUpdateTime = t;
        }

        requestAnimationFrame(frame);
    }

    resizeCanvas();
    requestAnimationFrame(frame);
})();