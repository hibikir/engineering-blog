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

We've looked at some common, simple ways implicits are used in every day scala. THere's one major common pattern that
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
   
 After the last few articles, we are prepared for this. The first implicit is an implicit conversion, that turns anything
 into a PimpedAny: So it gives any object an implementation of toJson.
 
 The method itself takes only a parameter: It's an implicit parameter, a JsonWriter of T. So for any type we want to serialize,
 we need to define a JsonWriter[T], and put it in the magic hat. Spray Json includes JsonWriters for basic types in that
 DefaultJsonProtocol.
 
 So, for a String:
 import spray.json._
 import DefaultJsonProtocol._
 
   val pony = "Fluttershy"
   val json = pony.toJson
   
 The implicits resolve to:
 
   val pony = "Fluttershy"
   val json = new PimpedAny[String](pony).toJson(DefaultJsonProtocol.StringJsonFormat)
  
  Which is closer to what our code would look like in a language without implicits.
  
  If we want to serialize our own classes, all we have to do is write JsonReaders for them. In the case of case classes,
   Spray has a mechanism to make it work:
   
   case class Pony(name:String, cutieMark:String)
   
   object Pony{
    implicit def jsonFormat = jsonFormat2(Pony.apply)
   }
   
But it works in pretty tricky ways, still full of implicits, and is out of scope for this post.
    
This pattern of typeclasses is used in most major libraries out there: Spray-routing also uses it for serialization
and returning data, although they call it 'magnet pattern'. Slick uses it too, to turn objects into database queries.
