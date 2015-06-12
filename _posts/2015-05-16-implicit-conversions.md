---
layout: post
title: "Learn implicits: Implicit Conversions"
subtitle: "You are using them already: Strings"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implicits, scala, tutorials]
extra_css:
  - implicits-intro.css
---

Implicit conversions, or as Typesafe likes to call them nowadays, views, are implicit parameter's more powerful, dangerous friend. 
They are very useful at avoding boilerplate, but used improperly can lead to a lot of confusion.

Despite the danger, I bet you've used them already. Let's look at a very simple example, using the scala REPL:

scala> val s = "a string"
s: String = a string

scala> s.getClass.getName
res1: String = java.lang.String

scala> val cap = s.capitalize
cap: String = A string

scala> cap.getClass.getName
res2: String = java.lang.String

so we have a plain Java String, and we capitalize it. Seems simple. I just called a method on an object. 
Except java.lang.String does not have a capitalize method. What sorcery is this?

As you'd be able to find with an IDE, the capitalize method is a part of scala.collection.immutable.StringLike.

def capitalize : scala.Predef.String

scala.Predef.String is just an alias for java.lang.String, so what happened is that somehow our String got converted into a StringLike,
to call capitalize. But we didn't do anything!

Scala automatically imports a few things for you, including scala.Predef. Predef has a whole lot of things in there, but this is the one that interests us:

implicit def augmentString(x : scala.Predef.String) : scala.collection.immutable.StringOps

What does this mean?

an implicit conversion is a single parameter function, prepended by the implicit keyword.
At any time a parameter or a method would not work the way they are, the compiler will attempt to use any implicit conversions
to make it match. The scoping of what you can put in implicit parameters is complicated.

StringOps extends StringLike, so we can call all it's methods on a string without having to do any manual wrapper. Convenient.

All this power comes with downsides. Conversions have to be put in scope, just like any
other implicit, and programmers have to know those conversions are available. Too many custom conversions make code harder to learn.
Another problem comes from using very wide conversions. Let's say that somewhere we defined classes that take a lot of options:

case class Something(name:Option[String], age:Option[Int], phoneNumber:Option[String])

If we always have the data, those Options are just noise, so anyone that just learned implicit conversions would write something like this!

implicit def optionify[T](t:T):Option[T] = Option(t)

Which lets us make this call work

val name = "Bob"
val age = 48
val phone = "(888)-444-3333"

val a = Something(name,age,phone)

Sounds great, right? We never have to wrap any values anymore! What's the worst that could happen?

Wherever that implicit is in scope, any syntax error that could be fixed by wrapping anything into an option will try to
be fixed that way, whether it makes sense or not.

val aList = ("a","b","c")
val anInt = 42
val something = Something("Bob",48,"(888)-444-3333")

aList.isEmpty
anInt.isEmpty
something.isEmpty

Only List has an isEmpty method, but the implicit conversion makes the other two work! That's not what we wanted with our
implicit conversion, but if we want that functionality, we have to keep this one too. Add a few more implicits like that
to the same scope, and suddenly you might as well be working in a language without types: The compiler stops being useful.

If we want to use this kind of implicit conversion responsibly, we have to add the implicits very explicitly, just for the
code than needs them

object AutoOption {
  implicit def optionify[T](t:T):Option[T] = Option(t)
}
  
class PutsThingsIntoOptionsAllTheTime{
  import AutoOption._
  
  ... put code that uses the implicit conversion here
  
}

There are two main cases where implicit conversions are relatively safe and unsurprising: When adding new functionality to a class,
and when trying to convert a class we cannot control to a subclass of another class we do control. Anything else is probably going
to be confusing.
