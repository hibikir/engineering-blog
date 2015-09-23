---
layout: post
title: "Learn implicits: Type classes"
subtitle: "Looking at how type classes work in Spray-json"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero/Jessica Kerr"
tags: [implicits, scala, tutorials, futures]
extra_css:
  - implicits-intro.css
---

<style scoped>
  .pimpedAny { color: #D907E8 }
  .implicitdef { color: #1AB955 }
  .implicitparam { color: #FF9C00 }
  .toJson {color: #BA182F }
  .jsValue {color: #08B9D1 }
  .contextbound {color: #D15308 }
</style>

In this series on Scala implicits, we have seen 
[some](http://engineering.monsanto.com/2015/05/14/implicits-intro/), 
[everyday](http://engineering.monsanto.com/2015/06/15/implicits-futures/), 
[uses](http://engineering.monsanto.com/2015/07/31/implicit-conversions/) of implicits. 
One crucial pattern combines these techniques: Type classes.

**Caution**: please excuse the name. "Type classes" resembles neither types nor classes in a way useful for understanding.
 The pattern is called "type classes" for historical reasons.

Type classes extend functionality of classes without actually changing them, and with full type safety.
This pattern is often used to add functionality to classes that we do not control. It's also useful for cross-cutting concerns.
 Serialization is a cross-cutting concern, and [spray-json](https://github.com/spray/spray-json) provides a practical example of the type class pattern.
 Let's see how it implements JSON serialization/deserialization for built-in classes.

[The documentation says](https://github.com/spray/spray-json#usage) that any object can have the .toJson method 
if we add a couple of imports.
<pre>
import spray.json._
import DefaultJsonProtocol._
</pre>
The two imports add some implicits to the compiler's magic hat. 

![the magic hat: implicit declarations go in, implicit parameter values come out](/img/typeclass-magic-hat-0.png)

`import spray.json._` brings in everything in the 
[spray json package object](https://github.com/spray/spray-json/blob/master/src/main/scala/spray/json/package.scala), including:

<pre>
{{"implicit def pimpAny[T](any: T)" | sc: "implicitdef"}} = new {{"PimpedAny"| sc: "pimpedAny""}}(any) 
private[json] class {{"PimpedAny[T]"| sc: "pimpedAny""}}(any: T) {
    def {{"toJson"| sc: "toJson""}}(implicit writer: JsonWriter[T]): {{"JsValue"| sc: "jsValue"}} = writer.write(any)
}
</pre>

 After the last few articles, we are ready for this. The first line is a {{"view" |sc:"implicitdef"}} that turns anything
 into a {{"PimpedAny"| sc: "pimpedAny""}}. Now every object in the world implements {{"toJson" |sc:"toJson"}}.
 We [warned](http://engineering.monsanto.com/2015/07/31/implicit-conversions/) against this kind of breadth in views,
 but here we are safe from surprises: the only way to activate this view is by calling {{".toJson" |sc:"toJson"}}. The intermediate class is invisible; you never even have to see its terrible name. The useful type is the {{"return value"| sc: "jsValue"}} of {{".toJson" |sc:"toJson"}}.

Calling {{"toJson" |sc:"toJson"}} transforms an object into a {{"JsValue"| sc: "jsValue"}}, a representation of JSON data.
 Two methods on {{"JsValue"| sc: "jsValue"}}, prettyPrint and compactPrint, return a String we can transmit or save.
 
Can we now serialize every single object, just like that? No. Not that easy. Here's the declaration again:
<pre>
def {{"toJson"| sc: "toJson""}}({{"implicit writer: JsonWriter[T]"| sc: "implicitparam"}}): {{"JsValue"| sc: "jsValue"}}
</pre>
This {{"toJson" |sc:"toJson"}} method takes an {{"implicit parameter"| sc: "implicitparam"}}, a JsonWriter of T.
So for any type T we want to convert to Json, there must be a JsonWriter[T], 
and it must be in the magic hat, in scope where {{"toJson" |sc:"toJson"}} is called. 

What is a JsonWriter[T], and where would the compiler find one?

JsonWriter is a trait with a single method, write.

    trait JsonWriter[T] {
      def write(obj: T): JsValue
    }

spray-json defines this trait, along with JsonReader for deserialization, and JsonFormat for both together. JsonFormat is the one we create, typically.
Spray-json has built-in JsonFormat implementations for many common types; these lurk in DefaultJsonProtocol. 
We bring all of them into implicit scope when we `import DefaultJsonProtocol._`. It's those JsonFormats that know how to serialize
and deserialize JSON.
 
For instance, there is an implicit JsonFormat[String]. In type class parlance, "There is an instance of the JsonFormat type class for String." We can use it like this:
<pre>
import spray.json._
import DefaultJsonProtocol._
 
val pony = "Fluttershy"
val json = pony.{{"toJson"| sc: "toJson""}}
</pre>
 The implicits resolve to:
<pre> 
val pony = "Fluttershy"
val json = new {{"PimpedAny"| sc: "pimpedAny""}}\[String\](pony).{{"toJson"| sc: "toJson""}}({{"DefaultJsonProtocol.StringJsonFormat"| sc: "implicitparam""}})
</pre>

This desugared syntax looks like serialization in a language without implicits.
  
This use of the type class pattern adds a whole feature (serialization) to any class we want, in a generic way,
without changing the classes. All the usual types (String, Int, Seq, Map, Option, etc) have serialization code in DefaultJsonFormat.

![the magic hat: importing DefaultJsonProtocol puts a JsonFormat of String in the hat](/img/typeclass-magic-hat-1.png)

For our own class T, we make {{".toJson"| sc: "toJson""}} work when we define an {{"implicit val of type JsonFormat[T]"| sc: "implicitparam""}}.
This is called "providing an instance of the JsonFormat type class for T." We can write these by hand, or use [helper methods](https://github.com/spray/spray-json#providing-jsonformats-for-case-classes) from spray-json.
There's even a [project](https://github.com/fommil/spray-json-shapeless) that makes the compiler generate it all for case classes;
 the details are way outside the scope of this post.

Here's the kicker: when we make a JsonFormat[MyClass], we get more than serialization/deserialization for MyClass.
We can now call {{"toJson"| sc: "toJson""}} on MyClass, Seq[MyClass], on Map[String,MyClass], on Option[Map[MyClass,List[MyClass]]] -- without writing any extra code!

This is the killer feature of the type class pattern: it composes.
One {{"generic definition of JsonFormat[List[T]]"|sc: "implicitdef"}} means a List of any JsonFormat-able T is also JsonFormat-able. T could be String, Int, Long, MyClass -- you name it, if we can format it, we can also format Lists of it.
Here's the trick: instead of an {{"implicit val"| sc: "implicitparam"}} for JsonFormat of List, there is an {{"implicit def"|sc: "implicitdef"}} in DefaultJsonFormat:

<pre>
    {{"implicit def"|sc: "implicitdef"}} listFormat[{{"T : JsonFormat"| sc: "contextbound"}}] = new RootJsonFormat[List[T]] {
      def write(list: List[T]) = ..
      def read(value: JsValue): List[T] = ..
    }
</pre>

What is this doing? First, we have to understand some new syntax: inside the {{"type parameter, there is a colon, followed by a type class"| sc: "contextbound"}}. 
This is called [Context Bounds](http://docs.scala-lang.org/tutorials/FAQ/context-and-view-bounds.html) (good luck finding the documentation without knowing this special name).
This is shorthand for "{{"a type T such that there exists in the magic hat a JsonFormat[T]"| sc: "contextbound"}}]".
The context-bounds notation above expands to:

<pre>
    implicit def listFormat[{{"T"| sc: "contextbound"}}]({{"implicit _ : JsonFormat[T]"| sc: "contextbound"}}) = new RootJsonFormat[List[T]] {
      def write(list: List[T]) = ..
      def read(value: JsValue): List[T] = ..
    }
</pre>

This guarantees that the write function inside listFormat will be able to call {{".toJson"| sc: "toJson""}} on the elements in the List.

This {{"implicit def"|sc: "implicitdef"}} does not work the same way as a [view]((http://engineering.monsanto.com/2015/07/31/implicit-conversions/)), which converts a single type to another.
Instead, it is is a supplier of implicit values. It can give the compiler a JsonFormat[List[T]],as long as the compiler supplies a JsonFormat[T]. 

![the magic hat: JsonDefaultProtocol puts in a function that turns an implicit JsonFormat of T into a JsonFormat of Seq of T](/img/typeclass-magic-hat-2.png)

This one definition composes with any other JsonFormats in the magic hat. 
The compiler calls as many of these implicit functions, as many times as needed, to produce the implicit parameter it desperately desires. 

![the magic hat: to satisfy the implicit parameter of type JsonFormat of Seq of T, the magic hat uses both these values](/img/typeclass-magic-hat-3.png)

This works on types as complicated as we want. Let's say we want to serialize an Option[Map[String,List[Int]]]:

    import spray.json._
    import DefaultJsonProtocol._

    val a:Option[Map[String,List[Int]]] = Some(Map("Applejack" -> List(1,2,3,4),"Fluttershy" -> List(2,4,6,8))) 
    val json = a.toJson
    println(json.prettyPrint)

The compiler uses implicit functions for Option, Map, and List, along with implicit vals for String and Int,
to compose a JsonFormat[Option[Map[String,List[Int]]]]. 
That gets passed into {{".toJson"| sc: "toJson""}}, and only then does serialization occur.
If we use the JsonFormats explicitly, the code above becomes:

    import spray.json._

    val a:Option[Map[String,List[Int]]] = Some(Map("Applejack" -> List(1,2,3,4),"Fluttershy" -> List(2,4,6,8)))

    val json = new PimpedAny[Option[Map[String,List[Int]]]](a).toJson(DefaultJsonProtocol.optionFormat(
                DefaultJsonProtocol.mapFormat(
                        DefaultJsonProtocol.StringJsonFormat,
                        DefaultJsonProtocol.listFormat(
                            DefaultJsonProtocol.IntJsonFormat
                        )
                )))
    println(json.prettyPrint)


Whew, that's a lot of magic. The compiler does all that composition for us. This property of composition makes the type class pattern very useful.

That much magic also means it's hard to understand. 
 While you'll rarely need to create your own types in the style of JsonFormat,
you'll often want to create new type class instances, such as JsonFormat[MyClass]. Other times you need to find the right ones to import.
Either way, familiarity with the pattern is essential when using spray-json and many other libraries.

spray-routing, a library used to write RESTful services, uses this pattern for a lot of things, including returning data, and to avoid some pitfalls of method overloading.
They call it the 'magnet pattern' and try to get you to read [a post much, much longer than this one](http://spray.io/blog/2012-12-13-the-magnet-pattern/).
Ultimately it's the same pattern, used for different properties.

In some ways, the type class pattern is the culmination of Scala's implicit feature. If this post makes sense, then you're well on your way to Scala mastery.
