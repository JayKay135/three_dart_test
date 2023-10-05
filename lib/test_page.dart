import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:flutter_gl/flutter_gl.dart';

import 'package:three_dart/three_dart.dart' as three;
import 'package:three_dart_jsm/three_dart_jsm.dart' as three_jsm;

class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with WidgetsBindingObserver {
  late FlutterGlPlugin three3dRender;
  three.WebGLRenderer? renderer;

  int? fboId;
  late double width;
  late double height;

  Size? screenSize;

  late three.Scene scene;
  late three.Camera camera;

  late three.Mesh mesh;
  late three.Group group;
  // late three.Texture texture;

  double dpr = 1.0;

  bool verbose = false;
  bool disposed = false;

  late three.WebGLRenderTarget renderTarget;

  late GlobalKey<three_jsm.DomLikeListenableState> _globalKey;

  late three_jsm.OrbitControls controls;

  dynamic sourceTexture;

  late bool resizing;
  DateTime? lastResize;

  @override
  void initState() {
    _globalKey = GlobalKey<three_jsm.DomLikeListenableState>();

    resizing = false;

    super.initState();

    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    disposed = true;
    //three3dRender.dispose();

    WidgetsBinding.instance.removeObserver(this);

    super.dispose();
  }

  @override
  void didChangeMetrics() {
    setState(() {
      resizing = true;
      lastResize = DateTime.now();

      checkForResizeEnd();
    });
  }

  Future<void> checkForResizeEnd() async {
    await Future.delayed(const Duration(milliseconds: 100));

    if (DateTime.now().difference(lastResize!) > const Duration(milliseconds: 100)) {
      setState(() {
        resizing = false;

        changeScreenSize();
      });
    }
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    width = screenSize!.width;
    height = screenSize!.height;

    three3dRender = FlutterGlPlugin();

    Map<String, dynamic> options = {"antialias": true, "alpha": false, "width": width.toInt(), "height": height.toInt(), "dpr": dpr};

    await three3dRender.initialize(options: options);

    setState(() {});

    // Wait for web
    Future.delayed(const Duration(milliseconds: 100), () async {
      await three3dRender.prepareContext();

      initScene();
    });
  }

  initSize(BuildContext context) {
    if (screenSize != null) {
      return;
    }

    final mqd = MediaQuery.of(context);

    screenSize = mqd.size;
    dpr = mqd.devicePixelRatio;

    initPlatformState();
  }

  void changeScreenSize() {
    screenSize = MediaQuery.of(context).size;

    width = screenSize!.width;
    height = screenSize!.height;

    renderer!.setPixelRatio(MediaQuery.of(context).devicePixelRatio);
    renderer!.setSize(width, height, true);

    initScene();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text(widget.fileName),
      // ),
      body: Builder(
        builder: (BuildContext context) {
          initSize(context);
          return SingleChildScrollView(child: _build(context));
        },
      ),
      // floatingActionButton: FloatingActionButton(
      //   child: const Text("render"),
      //   onPressed: () {
      //     render();
      //   },
      // ),
    );
  }

  Widget _build(BuildContext context) {
    return Column(
      children: [
        three_jsm.DomLikeListenable(
          key: _globalKey,
          builder: (BuildContext context) {
            if (resizing) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.green),
              );
            }

            return Container(
              width: width,
              height: height,
              color: Colors.red,
              child: Builder(
                builder: (BuildContext context) {
                  if (kIsWeb) {
                    return three3dRender.isInitialized ? HtmlElementView(viewType: three3dRender.textureId!.toString()) : Container();
                  } else {
                    return three3dRender.isInitialized ? Texture(textureId: three3dRender.textureId!) : Container();
                  }
                },
              ),
            );
          },
        ),
      ],
    );
  }

  render() {
    int t = DateTime.now().millisecondsSinceEpoch;

    final gl = three3dRender.gl;

    renderer!.render(scene, camera);

    int t1 = DateTime.now().millisecondsSinceEpoch;

    if (verbose) {
      print("render cost: ${t1 - t} ");
      print(renderer!.info.memory);
      print(renderer!.info.render);
    }

    // 重要 更新纹理之前一定要调用 确保gl程序执行完毕
    gl.flush();

    if (verbose) print(" render: sourceTexture: $sourceTexture ");

    if (!kIsWeb) {
      three3dRender.updateTexture(sourceTexture);
    }
  }

  initRenderer() {
    Map<String, dynamic> options = {"width": width, "height": height, "gl": three3dRender.gl, "antialias": true, "canvas": three3dRender.element};
    renderer = three.WebGLRenderer(options);
    renderer!.setPixelRatio(dpr);
    renderer!.setSize(width, height, false);
    renderer!.shadowMap.enabled = false;

    if (!kIsWeb) {
      var pars = three.WebGLRenderTargetOptions({"minFilter": three.LinearFilter, "magFilter": three.LinearFilter, "format": three.RGBAFormat});
      renderTarget = three.WebGLMultisampleRenderTarget((width * dpr).toInt(), (height * dpr).toInt(), pars);
      renderer!.setRenderTarget(renderTarget);
      sourceTexture = renderer!.getRenderTargetGLTexture(renderTarget);
    }
  }

  initScene() {
    initRenderer();
    initPage();
  }

  initPage() async {
    scene = three.Scene();
    scene.background = three.Color(0xcccccc);

    camera = three.PerspectiveCamera(60, width / height, 1, 2000);
    camera.position.set(400, 200, 0);

    scene.add(camera);

    controls = three_jsm.OrbitControls(camera, _globalKey);

    controls.enableDamping = true; // an animation loop is required when either damping or auto-rotation are enabled
    controls.dampingFactor = 0.05;

    controls.screenSpacePanning = false;

    controls.minDistance = 10;
    controls.maxDistance = 1000;

    controls.maxPolarAngle = three.Math.pi / 2;

    // grid helper
    three.GridHelper gridHelper = three.GridHelper(1000, 20, 0xff8400, 0x0095ff);
    gridHelper.position = three.Vector3(0, 0, 0);
    gridHelper.frustumCulled = false;
    scene.add(gridHelper);

    // 3d object
    var geometry = three.CylinderGeometry(10, 10, 30);
    var material = three.MeshPhongMaterial({"color": 0xff0000, "flatShading": true, "side": three.DoubleSide});

    var mesh = three.Mesh(geometry, material);
    scene.add(mesh);

    // axis
    three.Mesh xMesh = three.Mesh(three.CylinderGeometry(0.5, 0.5, 100), three.MeshPhongMaterial({"color": 0xff0000, "flatShading": false}));
    xMesh.position = three.Vector3(60, 0, 0);
    xMesh.setRotationFromEuler(three.Euler(0, 0, pi / 2));
    scene.add(xMesh);

    three.Mesh yMesh = three.Mesh(three.CylinderGeometry(0.5, 0.5, 100), three.MeshPhongMaterial({"color": 0x00ff00, "flatShading": false}));
    yMesh.position = three.Vector3(0, 60, 0);
    scene.add(yMesh);

    three.Mesh zMesh = three.Mesh(three.CylinderGeometry(0.5, 0.5, 100), three.MeshPhongMaterial({"color": 0x0000ff, "flatShading": false}));
    zMesh.position = three.Vector3(0, 0, 60);
    zMesh.setRotationFromEuler(three.Euler(pi / 2, 0, 0));
    scene.add(zMesh);

    // light
    var dirLight1 = three.DirectionalLight(0xffffff);
    dirLight1.position.set(10, 10, 10);
    scene.add(dirLight1);

    var dirLight2 = three.DirectionalLight(0x002288);
    dirLight2.position.set(-10, -10, -10);
    scene.add(dirLight2);

    var ambientLight = three.AmbientLight(0x222222);
    scene.add(ambientLight);

    animate();
  }

  animate() {
    if (!mounted || disposed) {
      return;
    }

    render();

    Future.delayed(const Duration(milliseconds: 40), () {
      animate();
    });
  }
}
