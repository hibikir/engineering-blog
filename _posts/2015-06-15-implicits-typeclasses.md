---
layout: post
title: "Learn implicits: Type classes"
subtitle: "Looking at how type classes work in Spray-json"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implicits, scala, tutorials, futures]
extra_css:
  - implicits-intro.css
---

<style scoped>
  
</style>

We've looked at some common ways implicits are used in every day scala. THere's one major common pattern that
combines a lot of the techniques we've used before: Type classes.

Type classes are a way to extend the functionality of classes without actually changing them, or losing type safety.
This pattern is often used on classes that we do not control, but it's also useful for cross cutting concerns. A good
example of this is serialization/deserialization. This is why we will use spray-json[LINK] as an example

The documentation claims that all we need to do to gain the .toJson method is to add a couple of imports.

import spray.json._
import DefaultJsonProtocol._

The two imports add some implicits to the magic hat. The first import includes everything in the [spray json package object](https://github.com/spray/spray-json/blob/master/src/main/scala/spray/json/package.scala)

In this file, we find the following code: 

 implicit def pimpAny[T](any: T) = new PimpedAny(any)
 
 private[json] class PimpedAny[T](any: T) {
     def toJson(implicit writer: JsonWriter[T]): JsValue = writer.write(any)
   }
   
 After the last few articles, we are ready for this. The first line is a view that turns anything
 into a PimpedAny: It gives any object an implementation of toJson. We warned against this in the post about views, but here we
have a good excuse: nothing uses the class we are converting to. Its whole purpose is to add a method that is unique to spray-json.
 
 ToJson takes an implicit parameter, a JsonWriter of T. So for any type T we want to convert to Json,
there must be a JsonWriter[T], and it must be in the magic hat at the time it's called.

JsonWriter is a trait with a single method, write.

trait JsonWriter[T] {
  def write(obj: T): JsValue
}

Along with this JsonWriter, there's also a JsonReader for deserialization, and a JsonFormat, which extends
both traits, and is the one we'd normally extend.
Spray Json has built-in JsonFormats for many commonly used types in DefaultJsonProtocol. That's why the
documentation instructs us to import DefaultJsonProtocol._.
 
 So, for a String:
 import spray.json._
 import DefaultJsonProtocol._
 
   val pony = "Fluttershy"
   val json = pony.toJson
   
 The implicits resolve to:
 
   val pony = "Fluttershy"
   val json = new PimpedAny[String](pony).toJson(DefaultJsonProtocol.StringJsonFormat)
  
  Which is closer to what using serialization libraries look like in a language without implicits.
  
The typeclass pattern has allowed us to add a complex feature, serialization, to any class we want, in a generic way,
without actually changing the classes. When we add features to a class through inheritance, we have to own the class,
and the extra features need to be added in all the time, making our classes bigger.
 If instead we use a wrapper class, we lose the original type of the class. Using views alone, we have to reimplement
the feature from the beginning on every class. Typeclasses offer what, in many cases is a better solution.
  
This pattern of typeclasses is used in most major libraries out there: Spray-routing also uses it for serialization
and returning data, although they call it 'magnet pattern'. Slick uses it too, to turn objects into database queries.



/////////taken out 


  If we want to serialize our own classes, all we have to do is write JsonReaders for them. In the case of case classes,
   Spray has a helper mechanism to make it work:
   
   case class Pony(name:String, cutieMark:String)
   
   object Pony{
    implicit def jsonFormat = jsonFormat2(Pony.apply)
   }
   
But the way it works is fairly complex, and is out of scope for this post.
    