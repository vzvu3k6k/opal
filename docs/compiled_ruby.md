# Compiled Ruby Code

## Generated JavaScript

Opal is a source-to-source compiler, so there is no VM as such and the
compiled code aims to be as fast and efficient as possible, mapping
directly to underlying javascript features and objects where possible.

### Literals

```ruby
nil         # => nil
true        # => true
false       # => false
self        # => self
```

**self** is mostly compiled to `this`. Methods and blocks are implemented
as javascript functions, so their `this` value will be the right
`self` value. Class bodies and the top level scope use a `self` variable
to improve readability.

**nil** is compiled to a `nil` javascript variable. `nil` is a real object
which allows methods to be called on it. Opal cannot send methods to `null`
or `undefined`, and they are considered bad values to be inside ruby code.

**true** and **false** are compiled directly into their native boolean
equivalents. This makes interaction a lot easier as there is no need
to convert values to opal specific values.

NOTE: Because `true` and `false` compile to their native
javascript equivalents, they must share the same class: `Boolean`.
Thru some level of hackery, we make them pseudo-members of the appropriate
`TrueClass` and `FalseClass`.

#### Strings & Symbols

```ruby
"hello world!"    # => "hello world!"
:foo              # => "foo"
<<-EOS            # => "Hello there.\n"
Hello there.
EOS
```

Ruby strings are compiled directly into JavaScript strings for
performance as well as readability. This has the side effect that Opal
does not support mutable strings - i.e. all strings are immutable.

NOTE: Strings in Opal are immutable because they are compiled into regular JavaScript strings. This is done for performance reasons.

For performance reasons, symbols are also compiled directly into strings.
Opal supports all the symbol syntaxes, but does not have a real `Symbol`
class. Symbols and Strings can therefore be used interchangeably.

#### Numbers

In Opal there is a single class for numbers; `Number`. To keep Opal
as performant as possible, Ruby numbers are mapped to native numbers.
This has the side effect that all numbers must be of the same class.
Most relevant methods from `Integer` and `Float` are implemented on
this class.

```ruby
42        # => 42
3.142     # => 3.142
```

#### Arrays

Ruby arrays are compiled directly into JavaScript arrays. Special
Ruby syntaxes for word arrays etc are also supported.

```ruby
[1, 2, 3, 4]        # => [1, 2, 3, 4]
%w[foo bar baz]     # => ["foo", "bar", "baz"]
```

#### Hash

Inside a generated Ruby script, a function `Opal.hash` is available which
creates a new hash. This is also available in JavaScript as `Opal.hash`
and simply returns a new instance of the `Hash` class.

```ruby
{ :foo => 100, :baz => 700 }    # => Opal.hash("foo", 100, "baz", 700)
{ foo: 42, bar: [1, 2, 3] }     # => Opal.hash("foo", 42, "bar", [1, 2, 3])
```

#### Range

Similar to hash, there is a function `Opal.range` available to create
range instances.

```ruby
1..4        # => Opal.range(1, 4, true)
3...7       # => Opal.range(3, 7, false)
```

### Logic and conditionals

As per Ruby, Opal treats only `false` and `nil` as falsy, everything
else is a truthy value including `""`, `0` and `[]`. This differs from
JavaScript as these values are also treated as false.

For this reason, most truthy tests must check if values are `false` or
`nil` (we also check for `null` and `undefined`).

Taking the following test:

```ruby
val = 42

if val
  return 3.142;
end
```

This would be compiled into:

```javascript
val = 42;
if (val !== false && val !== nil && val != null) {
  return 3.142
} else {
  return nil
};
```

This makes the generated truthy tests (`if` statements, `and` checks and
`or` statements) a little more verbose in the generated code.

### Instance variables

Instance variables in Opal work just as expected. When ivars are set or
retrieved on an object, they are set natively without the `@` prefix.
This allows real JavaScript identifiers to be used which is more
efficient then accessing variables by string name.

```ruby
@foo = 200
@foo  # => 200

@bar  # => nil
```

This gets compiled into:

```javascript
this.foo = 200;
this.foo;   // => 200

this.bar;   // => nil
```

NOTE: If an instance variable uses the same name as a reserved JavaScript keyword,
then the instance variable is wrapped using the object-key notation: `this['class']`.

## Compiled Files

As described above, a compiled Ruby source gets generated into a string
of JavaScript code that is wrapped inside an anonymous function. This
looks similar to the following:

```javascript
(function(Opal) {
  // some setup code code
  return self.$puts("foo")
})(Opal);
```

As a complete example, assuming the following code:

```ruby
puts "foo"
```

This would compile directly into:

```javascript
Opal.queue(function(Opal) {
  var self = Opal.top, nil = Opal.nil;

  Opal.add_stubs('puts');
  return self.$puts("foo")
});
```

**TIP:**

you can see the compiled code with this command: `opal --compile --no-exit --no-opal --eval 'puts "foo"'`
or, more briefly: `opal -cEO -e 'puts "foo"'`


### Using compiled sources

If you write the generated code as above into a file `app.js` and add
that to your HTML page, then it is obvious that `"foo"` would be
written to the browser's console.

### Debugging and finding errors

Because Opal does not aim to be fully compatible with Ruby, there are
some instances where things can break and it may not be entirely
obvious what went wrong.

### Using JavaScript debuggers

As Opal just generates JavaScript, it is useful to use a native
debugger to work through JavaScript code. To use a debugger, simply
add a `debugger` statement:

```ruby
# .. code
debugger
# .. more code
```

The `debugger` statement is compiled to become a JavaScript `debugger`
statement. This statement breaks the code if you have your Inspector open.

NOTE: All local variables and method/block arguments also keep their Ruby
names except in the rare cases when the name is reserved in JavaScript.
In these cases, a `$` suffix is added to the name
(e.g. `try` → `try$`).


## JavaScript from Ruby

Opal tries to interact as cleanly with JavaScript and its api as much
as possible. Ruby arrays, strings, numbers, regexps, blocks and booleans
are just JavaScript native equivalents. The only boxed core features are
hashes.


### Inline JavaScript

As most of the corelib deals with these low level details, Opal provides
a special syntax for inlining JavaScript code. This is done with
x-strings or "backticks", as their Ruby use has no useful translation
in the browser.

```ruby
`window.title`
# => "Opal: Ruby to JavaScript compiler"

%x{
  console.log("opal version is:");
  console.log(#{ RUBY_ENGINE_VERSION });
}

# => opal version is:
# => 1.3.1
```

Even interpolations are supported, as seen here.

This feature of inlining code is used extensively, for example in
Array#length:

```ruby
class Array
  def length
    `this.length`
  end
end
```

X-Strings also have the ability to automatically return their value,
as used by this example.


### Native Module

_Reposted from: [Mikamayhem](http://dev.mikamai.com/post/79398725537/using-native-javascript-objects-from-opal)_

Opal standard lib (stdlib) includes a `Native` module. To use it, you need to download and reference `native.js`. You can find the latest minified one from the CDN [here](http://cdn.opalrb.com/opal/current/native.min.js).

Let's see how it works and wrap `window`:

```ruby
require 'native'

win = Native(`window`) # equivalent to Native::Object.new(`window`)
```

To access a Native-wrapped global JavaScript object, we can also use `$$`, after
we have the `native` module required.

Now what if we want to access one of its properties?

```ruby
win[:location][:href]                         # => "http://dev.mikamai.com/"
win[:location][:href] = "http://mikamai.com/" # will bring you to mikamai.com
```

And what about methods?

```ruby
win.alert('hey there!')
```

So let’s do something more interesting:

```ruby
class << win
  # A cross-browser window close method (works in IE!)
  def close!
    %x{
      return (#@native.open('', '_self', '') && #@native.close()) ||
             (#@native.opener = null && #@native.close()) ||
             (#@native.opener = '' && #@native.close());
    }
  end

  # let's assign href directly
  def href= url
    self[:location][:href] = url
  end
end
```

That’s all for now, bye!

```ruby
win.close!
```

### Calling JavaScript Methods

You can make direct JavaScript method calls on using the `recv.JS.method`
syntax.  For example, if you have a JavaScript object named `foo` and want to call the
`bar` method on it with no arguments, with or without parentheses:

```ruby
# javascript: foo.bar()
foo.JS.bar
foo.JS.bar()
```

You can call the JavaScript methods with arguments, with or without parentheses, just
like Ruby methods:

```ruby
# JavaScript: foo.bar(1, "a")
foo.JS.bar(1, :a)
foo.JS.bar 1, :a
```

You can call the JavaScript methods with argument splats:

```ruby
# JavaScript: ($a = foo).bar.apply($a, [1].concat([2, 3]))
foo.JS.bar(1, *[2, 3])
foo.JS.bar 1, *[2, 3]
```

You can provide a block when making a JavaScript method call, and it will be
converted to a JavaScript function added as the last argument to the method:

```ruby
# JavaScript:
# ($a = (TMP_1 = function(arg){
#     var self = TMP_1.$$s || this;
#     if (arg == null) arg = nil;
#     return "" + (arg.method()) + " " + (self.$baz(3))
#    },
#    TMP_1.$$s = self, TMP_1),
# foo.bar)(1, 2, $a);
foo.JS.bar(1, 2){|arg| arg.JS.method + baz(3)}
```

Note how `self` is set for the JavaScript function passed as an argument.  This
allows normal Ruby block behavior to work when passing blocks to JavaScript
methods.

The `.JS.` syntax is recognized as a special token by the lexer, so if you have
a Ruby method named `JS` that you want to call, you can add a space to call it:

```ruby
# call Ruby JS method on foo, call Ruby bar method on result
foo. JS.bar
```

### Getting/Setting JavaScript Properties

You can get JavaScript properties using the `recv.JS[:property]` syntax:

```ruby
# JavaScript: foo["bar"]
foo.JS[:bar]
```

This also works for JavaScript array access:

```ruby
# JavaScript: foo[2]
foo.JS[2]
```

You can set JavaScript properties using this as the left hand side in an
assignment:

```ruby
# JavaScript: foo["bar"] = 1
foo.JS[:bar] = 1
```

This also works for setting values in a JavaScript array:

```ruby
# JavaScript: foo[2] = "a"
foo.JS[2] = :a
```

Like the `recv.JS.method` syntax, `.JS[` is recognized as a special token by
the lexer, so if you want to call the Ruby `JS` method on a object and then
call the Ruby `[]` method on the result, you can add a space:

```ruby
# call Ruby JS method on foo, call Ruby [] method on result with :a argument
foo. JS[:a]
```

### Calling JavaScript Operators

Opal has a `js` library in the stdlib that provides a `JS` module which can
be used to call JavaScript operators such as `new`.  Example:

```ruby
require 'js'

# new foo(bar)
JS.new(foo, bar)

# delete foo["bar"]
JS.delete(foo, :bar)

# "bar" in foo
JS.in(:bar, foo)

# foo instanceof bar
JS.instanceof(foo, bar)

# typeof foo
JS.typeof(foo)
```

### Calling JavaScript Global Functions

You can also use the `js` library to call JavaScript global functions via
`JS.call`:

```ruby
require 'js'

# parseFloat("1.1")
JS.call(:parseFloat, "1.1")
```

For convenience, `method_missing` is aliased to call, allowing you to call
global JavaScript methods directly on the `JS` module:

```ruby
require 'js'

# parseFloat("1.1")
JS.parseFloat("1.1")
```


### Wrapping JavaScript Libraries

If you want to integrate a JavaScript library with Opal, so that you can make Ruby calls, you can choose one of the following options:

- **Use backticks:** This is the quickest, simplest approach to integrating: call the native JavaScript code directly; it may provide a slight performance benefit, but also produces "ugly" Ruby code riddled with JavaScript. It's ideal for occasional calls to a JavaScript library.

- **Use `.JS`:** You can make direct JavaScript method calls on using the `recv.JS.method` syntax.  It is very similar to using backticks but looks more like ruby.

- **Use `Native`:** `Native` provides a reasonable Ruby-like wrapper around JavaScript objects. This provides a quick in-term solution if no dedicated Ruby wrapper library exists.

- **Create your own Wrapper Library:** If you use the library a lot, you can create your own Ruby library that wraps the JavaScript calls (which call `Native` or use backticks under the hood). This provides the best abstraction (eg. you can provide high-level calls that provide functionality, regardless of if the underlying JavaScript call flows change).


## Ruby from JavaScript

Accessing classes and methods defined in Opal from the JavaScript runtime is
possible via the `Opal` JS object. Consider following code:

```ruby
module Bar
  BAR = 123
end

class Foo
  include Bar
  FOO = 456

  def foo
    puts "called #foo on class ::Foo defined in Ruby code"
  end
end

BAZ = 789
```

### Navigating constants

Top level constants can be accessed as properties of `Opal`:


```javascript
Opal.Object;       // => Object
Opal.Kernel;       // => Kernel
Opal.Array;        // => Array
Opal.RUBY_VERSION; // => "2.3"
Opal.Foo;          // => Foo
Opal.BAZ;          // => 789
```

To reach nested constants the safest way is to call `#const_get` on `Object`:

```javascript
Opal.Object.$const_get('Bar::BAR'); // => 123
Opal.Object.$const_get('Foo::BAR'); // => 123
Opal.Object.$const_get('Foo::FOO'); // => 456
Opal.Object.$const_get('BAZ');      // => 789
```

Constants can also be navigated using the `$$` property, although this is limited to constants defined directly under the current object:

```javascript
Opal.Bar.$$.BAR // => 123
Opal.Foo.$$.FOO // => 456
Opal.Foo.$$.BAR // => undefined
```

A later feature also allows you to skip the `$$` property:

```javascript
Opal.Bar.BAR // => 123
Opal.Foo.FOO // => 456
Opal.Foo.BAR // => undefined
```


### Calling methods

**Methods** are always prefixed by a single `$`:

```javascript
// Equivalent to:
//   Foo.new.foo
Opal.Foo.$new().$foo(); // => "called #foo on class ::Foo defined in Ruby code"

// Equivalent to:
//   "hello there".sub('there', 'world')
("hello there").$sub('there', 'world'); // => "hello world"
```

**Methods names unsupported in JS** should be called using the JS bracket notation:

```javascript
// Equivalent to:
//   hash = Hash.new["key"] = "value"
//   hash["key"] = "value"
var hash = Opal.Hash.$new();  // => {}
hash["$[]="]("key", "value"); // => "value"

// Equivalent to:
//   [1,2,3].reverse!
[1,2,3]['$reverse!'](); // => [3,2,1]

// Equivalent to:
//   1 == 2
(1)['$=='](2); // => false
```

**Passing blocks** from JS is a bit more tricky, so the suggested solution is to use `Opal.send(…)`:

```javascript
// Equivalent to:
//   [1,2,3].map {|n| n * 2}
Opal.send([1,2,3], 'map', [], function(n) {return n * 2}); // => [2,4,6]
```

Alternatively blocks can also be called *the hard way* by assigning the block-function to the property `$$p` of the method:

```javascript
// Equivalent to:
//   [1,2,3].map {|n| n * 2}
array = [1,2,3]
array.$map.$$p = function(n) {return n * 2}; // "$$p" stands for "proc"
array.$map(); // => [2,4,6]
```



### Hash

Since Ruby hashes are implemented directly with an Opal class, there's no "toll-free" bridging available (unlike with strings and arrays, for example). However, it's quite possible to interact with hashes from JavaScript:

```javascript
var myHash = Opal.hash({a: 1, b: 2});
// output of $inspect: {"a"=>1, "b"=>2}
myHash.$store('a', 10);
// output of $inspect: {"a"=>10, "b"=>2}
myHash.$fetch('b','');
// 2
myHash.$fetch('z','');
// ""
myHash.$update(Opal.hash({b: 20, c: 30}));
// output of $inspect: {"a"=>10, "b"=>20, "c"=>30}
myHash.$to_n(); // provided by the Native module
// output: {"a": 10, "b": 20, "c": 30} aka a standard JavaScript object
```

NOTE: Be aware `Hash#to_n` produces a duplicate copy of the hash.


### Freezing Objects

Starting with Opal 1.6.0 freezing objects is supported in general but a few differences to Ruby apply.
Contrary to Ruby, where #freeze is often used to optimize performance, there is no performance benefit when freezing objects in Opal, instead its main use case is to prevent modification of objects.
There are a few edge cases, where accessing frozen objects in Opal behaves different from Ruby. In those cases a modification attempt will fail silently, with no "FrozenError" exception thrown.


## Advanced Compilation

### Method Missing

Opal supports `method_missing`. This is a key feature of Ruby, and Opal wouldn't be much use without it! This page details the implementation of `method_missing` for Opal.

#### Method dispatches

Firstly, a Ruby call `foo.bar 1, 2, 3` is compiled into the following JavaScript:

```javascript
foo.$bar(1, 2, 3)
```

This should be pretty easy to read. The `bar` method has a `$` prefix just to distinguish it from underlying JavaScript properties, as well as Ruby ivars. Methods are compiled like this to make the generated code really readable.

#### Handling `method_missing`

JavaScript does not have an equivalent of `method_missing`, so how do we handle it? If a function is missing in JavaScript, then a language level exception will be raised.

To get around this, we make use of our compiler. During parsing, we collect a list of all method calls made inside a Ruby file, and this gives us a list of all possible method calls. We then add stub methods to the root object prototype (an Opal object, not the global JavaScript Object) which will proxy our method missing calls for us.

For example, assume the following Ruby script:

```ruby
first 1, 2, 3
second "wow".to_sym
```

After parsing, we know we only ever call 3 methods: `[:first, :second, :to_sym]`. So, imagine we could just add these 3 methods to `BasicObject` in Ruby, we would get something like this:

```ruby
class BasicObject
  def first(*args, &block)
    method_missing(:first, *args, &block)
  end

  def second(*args, &block)
    method_missing(:second, *args, &block)
  end

  def to_sym(*args, &block)
    method_missing(:to_sym, *args, &block)
  end
end
```

It is obvious from here, that unless an object defines any given method, it will always resort in a dispatch to `method_missing` from one of our defined stub methods. This is how we get `method_missing` in Opal.

#### Optimising generated code

To optimise the generated code slightly, we reduce the code output from the compiler into the following JavaScript:

```javascript
Opal.add_stubs("first,second,to_sym"]);
```

You will see this at the top of all your generated JavaScript files. This will add a stub method for all methods used in your file.

#### Alternative approaches

The old approach was to inline `method_missing` calls by checking for a method on **every method dispatch**. This is still supported via a parser option, but not recommended.
