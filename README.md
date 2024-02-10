# mojo-pixel-war

过年的时候突然想起是不是可以做一个像素画小游戏来玩。然后就做了一个。

## 现状

![image](https://github.com/jyi2ya/mojo-pixel-war/assets/86813521/ed7b799b-9b60-4b1f-9b0b-e76f2a2e8508)

## 怎么玩

mojo-pixel-war 提供三个 API：

`POST /draw` ：在画布的指定坐标绘制指定颜色的图案

参数采用 `post_form` 的形式：

* x：坐标的列号
* y：坐标的行号
* color：要绘制的颜色，使用 #RRGGBB 格式

返回一个 JSON，有 `reason` 和 `result` 两个域。

* result：绘制结果。`OK`表示绘制成功
* reason：失败原因

`GET /view` ：查看当前画布的状态，返回 HTML 格式。

`GET /status`：查看当前画面的状态，返回 JSON 格式。有三个域。

* width：画布宽度
* height：画布高度
* canvas：数组，里面是画布上各像素点的颜色。按照从上到下，从左到右的顺序排列。

## 依赖

* Mojolicious

## 可选依赖

* Mojolicious::Plugin::CORS（如果你要写一个前端并调用 mojo-pixel-war 的相关接口的话，就需要这个）

## 部署运行

首先

```shell
cpan Mojolicious
```

然后

```shell
perl main.pl
```

就可以了

## 命令行选项说明

```plain
  -w --width <i32>   canvas width (default: 96)
  -H --height <i32>  canvas height (default: 64)
  -a --address <str> address to listen on (default: 0.0.0.0)
  -p --port <i16>    port to use (default: 8086)
  -s --save <str>    path to saved data (default: ./saved.data)
     --save-interval time between two saves in seconds (default: 60)
  -m --mode <str>    mode. 'debug' or 'production' (default: production)
  -h --help          print help page and exit
```
