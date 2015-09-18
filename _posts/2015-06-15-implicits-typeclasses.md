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
  
</style>

In this series on Scala implicits, we have looked at some everyday uses of implicits: 
[reflection](http://engineering.monsanto.com/2015/05/14/implicits-intro/), 
[repetitive parameters](http://engineering.monsanto.com/2015/06/15/implicits-futures/), 
[adding methods](http://engineering.monsanto.com/2015/07/31/implicit-conversions/). 
One major common pattern combines a lot of these techniques: Type classes.

Caution: please excuse the name. "Type classes" resembles neither types nor classes in a way useful for understanding.
 The pattern is called "type classes" for historical reasons.

Type classes extend the functionality of classes without actually changing them, and without losing type safety.
This pattern is often used on classes that we do not control, but it's also useful for cross-cutting concerns.
 Serialization is a cross-cutting concern, and [spray-json](https://github.com/spray/spray-json) provides an excellent example.
 Let's see how it implements low-overhead JSON serialization/deserialization using type classes.

[The documentation claims](https://github.com/spray/spray-json#usage) that any object can have the .toJson method 
if we add a couple of imports.

    import spray.json._
    import DefaultJsonProtocol._

The two imports add some implicits to the compiler's magic hat. 

![the magic hat: implicit declarations go in, implicit parameter values come out]("img/typeclass-magic-hat-0.png")

The first import brings in everything in the 
[spray json package object](https://github.com/spray/spray-json/blob/master/src/main/scala/spray/json/package.scala)

In this file, we find the following code: 

     implicit def pimpAny[T](any: T) = new PimpedAny(any)
 
     private[json] class PimpedAny[T](any: T) {
         def toJson(implicit writer: JsonWriter[T]): JsValue = writer.write(any)
     }
   
 After the last few articles, we are ready for this. The first line is a view[color] that turns anything
 into a PimpedAny[color]. Now any object implements toJson.
 We [warned](http://engineering.monsanto.com/2015/07/31/implicit-conversions/) against this kind of breadth in views,
 but here we are safe from surprises: nothing uses the class we are converting to.
 This view adds a method that is unique to spray-json;
 calling this method is the only way to trigger the compiler to pull this view out of its hat and transform any object.

Calling toJson on an object transforms it into a JsValue, a representation of JSON data.
 It has two methods, prettyPrint and compactPrint, that return a String we can transmit or save.
 
But does any object really implement JSON serialization, just like that? No.
This toJson method takes an implicit parameter, a JsonWriter of T.
So for any type T we want to convert to Json, there must be a JsonWriter[T], 
and it must be in the magic hat at the scope where toJson is called. 

What is a JsonWriter[T], and where would the compiler find one?

JsonWriter is a trait with a single method, write.

    trait JsonWriter[T] {
      def write(obj: T): JsValue
    }

spray-json defines this trait, along with JsonReader for deserialization, and JsonFormat for both together. JsonFormat is most often defined.
Spray-json has built-in JsonFormat implementations for many common types; these lurk in DefaultJsonProtocol. 
We bring all of them into implicit scope when we import DefaultJsonProtocol._.
 
For instance, there is an implicit JsonFormat[String]. In type class parlance, "There is an instance of the JsonFormat type class for String." We can use it like this:

    import spray.json._
    import DefaultJsonProtocol._
 
    val pony = "Fluttershy"
    val json = pony.toJson
   
 The implicits resolve to:
 
    val pony = "Fluttershy"
    val json = new PimpedAny[String](pony).toJson(DefaultJsonProtocol.StringJsonFormat)
  
This is pretty much what serialization looks like in a language without implicits.
  
This use of the type class pattern adds a complex feature (like serialization) to any class we want, in a generic way,
without changing the classes. The usual types have serialization code in DefaultJsonFormat.

![the magic hat: importing DefaultJsonProtocol puts a JsonFormat of String in the hat]("img/typeclass-magic-hat-1.png")

For our own class T, we can get access to the .toJson method by defining an implicit val of type JsonFormat[T].
This is called "providing an instance of the JsonFormat type class for T.") spray-json defines 
[helper methods to help with this](https://github.com/spray/spray-json#providing-jsonformats-for-case-classes).
There's also a [project](https://github.com/fommil/spray-json-shapeless) that generates them by adding an import ;
 the details are outside the scope of this post.

Here's the kicker: when we make a JsonFormat[T], we get more than serialization/deserialization for T.
We can now call toJson on Seq[T], on Map[String,T], on Option[Map[T,List[T]]] ... the possibilities are endless!

This is the killer feature of the type class pattern: it composes.
With one definition for a JsonFormat[List[T]], a List of any JsonFormat-able T is suddenly JsonFormat-able.
Here's the trick --instead of supplying an implicit val for JsonFormat of List, there is an implicit def in DefaultJsonFormat._:

  implicit def listFormat[T :JsonFormat] = new RootJsonFormat[List[T]] {
    def write(list: List[T]) = ..
    def read(value: JsValue): List[T] = ..
  }

What is this doing? First, we have to understand some new syntax: inside the type parameter[COLOR]. 
This is called [Context Bounds](http://docs.scala-lang.org/tutorials/FAQ/context-and-view-bounds.html):
Those are the words to find documentation. This is a shorthand for "a type T such that there exists in the magic hat a JsonFormat[T]".
The compiler expands the listFormat function declaration to:

implicit def listFormat[T](implicit _ : JsonFormat[T]) = new RootJsonFormat[List[T]] {
    def write(list: List[T]) = ..
    def read(value: JsValue): List[T] = ..
}

This guarantees that the write function inside listFormat will be able to call .toJson on the elements in the List.

This implicit def does not work the same way as a view[LINK]((http://engineering.monsanto.com/2015/07/31/implicit-conversions/)), which converts one type to another.
Instead, it is is a supplier of implicit values. It can give the compiler a JsonFormat[List[T]],as long as the compiler supplies a JsonFormat[T]. 

![the magic hat: JsonDefaultProtocol puts in a function that turns an implicit JsonFormat of T into a JsonFormat of Seq of T]("img/typeclass-magic-hat-2.png")

This one definition composes with any other JsonFormats in the magic hat. 
The compiler calls as many of these implicit functions, as many times as needed, to produce the implicit parameter it desperately desires. 

![the magic hat: to satisfy the implicit parameter of type JsonFormat of Seq of T, the magic hat uses both these values]("img/typeclass-magic-hat-3.png")

This can go on and on. When you import DefaultJsonProtocol._ and then call .toJson on an Option[Map[String,List[Int]]],
the compiler uses implicit functions for Option, Map, and List, along with implicit vals for String and Int,
to compose a JsonFormat[Option[Map[String,List[Int]]]]. That gets passed into .toJson, and only then does serialization occur.

Whew, that's a lot of magic. This property of composition makes the type class pattern very useful.
Just imagine how much boilerplate it would take to do this without implicits!
That much magic also means it's hard to understand: 
 While you'll rarely need to create your own types in the style of JsonFormat,
you'll often want to create new type class instances. 
Other times you need to find the right ones to import;
spray-routing uses this pattern for returning data, 
although they call it the 'magnet pattern' and try to get you to read [a post much, much longer than this one](http://spray.io/blog/2012-12-13-the-magnet-pattern/).
In some ways, this is the culmination of Scala's implicit pattern. If this post makes sense, then you're well on your way to Scala mastery.


This pattern of typeclasses is used in most major libraries out there: Spray-routing also uses it for serialization
and returning data, although they call it 'magnet pattern'. Slick uses it too, to turn objects into database queries.
