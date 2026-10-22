import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        // 改造一：种子色由 deepPurple 换成 teal，整站配色随之改变。
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() {
    print('[lifecycle] createState()：框架第一次需要 State 时调用，返回 _MyHomePageState');
    return _MyHomePageState();
  }
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  /// 改造一：每次点击 FAB 的增量，可在 AppBar 的按钮里选择 1 / 2 / 5。
  int _step = 1;

  // ---------- 改造二：生命周期日志（每个钩子一行 print） ----------

  @override
  void initState() {
    super.initState();
    print('[lifecycle] initState()：State 插入树中，只调用一次（适合做一次性初始化）');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    print('[lifecycle] didChangeDependencies()：所依赖的 InheritedWidget 变化后调用');
  }

  @override
  void didUpdateWidget(covariant MyHomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[lifecycle] didUpdateWidget()：父级传下新配置，title 由 ${oldWidget.title} 变为 ${widget.title}');
  }

  @override
  void deactivate() {
    super.deactivate();
    print('[lifecycle] deactivate()：State 暂时离开树（随后可能被重新插入，也可能进入 dispose）');
  }

  @override
  void dispose() {
    print('[lifecycle] dispose()：State 永久销毁，在这里释放资源');
    super.dispose();
  }

  void _incrementCounter() {
    setState(() {
      // 改造一：增量由固定 +1 改为 +_step（默认 1，即“每点 +1”的旧行为）。
      _counter += _step;
    });
  }

  /// 改造一：打开底部弹层，让用户选择步长（1 / 2 / 5）。
  Future<void> _chooseStep() async {
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(dense: true, title: Text('选择每次点击的步长')),
            for (final value in const [1, 2, 5])
              ListTile(
                title: Text('步长 $value'),
                trailing: value == _step ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheetContext, value),
              ),
          ],
        ),
      ),
    );
    // await 之后 State 可能已被销毁，必须先检查 mounted 再 setState。
    if (!mounted || selected == null) return;
    setState(() => _step = selected);
  }

  @override
  Widget build(BuildContext context) {
    print('[lifecycle] build()：重建中，当前 _counter=$_counter, _step=$_step');
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        // 改造一：AppBar 右上角加入口，点开弹层选步长。
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: '设置步长',
            onPressed: _chooseStep,
          ),
        ],
        // 改造二：用 assets 里的自定义图片作 AppBar 背景（BoxFit.cover 自动裁剪）。
        flexibleSpace: Image.asset(
          'assets/images/appbar_bg.jpg',
          fit: BoxFit.cover,
          // 压暗一点，保证白色标题文字在图片上依然清晰。
          color: Colors.black38,
          colorBlendMode: BlendMode.darken,
        ),
        foregroundColor: Colors.white,
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: .center,
          children: [
            const Text('You have pushed the button this many times:'),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            // 改造一：把当前步长显示出来，方便验证。
            // 主题取用：文字样式取自 Theme，颜色取自 teal 种子色生成的主色。
            Text(
              '步长：+$_step / 次',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment by $_step',
        child: const Icon(Icons.add),
      ),
    );
  }
}
