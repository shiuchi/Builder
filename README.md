# Builder
DIContainer for as3!!!!!

```ActionScript

class ClassA {
  var b : ClassB
}

class ClassB {
  var a : ClassA
}

var a:ClassA = new ClassA();
var b:ClassB = new ClassB();

var builder = new Builder();
builder.register(a);
builder.register(b);
builder.create();

trace(a.b)
trace(b.a)

```
