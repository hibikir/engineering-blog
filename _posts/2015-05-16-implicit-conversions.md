---
layout: post
title: "Learn implicits: Views"
subtitle: "You are using them already: Strings"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implicits, scala, tutorials]
extra_css:
  - implicits-intro.css
---

Views, also called implicit conversions, are a powerful and dangerous friend. 
They are useful for avoiding boilerplate, but used improperly they lead to confusion.

Even if you didn't know they existed, I bet you've used them already. Let's look at a very simple example, using the scala REPL:

<pre>
scala> val s = "fluttershy"
s: String = fluttershy

scala> s.getClass.getName
res1: String = java.lang.String

scala> val cap = s.capitalize
cap: String = Fluttershy

scala> cap.getClass.getName
res2: String = java.lang.String
</pre>

so we have a plain Java String, and we capitalize it. Seems simple. I just called a method on an object. 
Except java.lang.String does not have a capitalize method! What sorcery is this?

![IntelliJ understands capitalize](/img/capitalize.png)

As IntelliJ tells us, the capitalize method is a part of [StringLike](https://github.com/scala/scala/blob/6ca8847eb5891fa610136c2c041cbad1298fb89c/src/library/scala/collection/immutable/StringLike.scala#L141).

    trait StringLike[+Repr] extends Any with scala.collection.IndexedSeqOptimized[Char, Repr]
     with Ordered[String] {
        def capitalize : scala.Predef.String

(where scala.Predef.String is an alias for java.lang.String. <- maybe footnote this?) 
Somehow our String got converted into a StringLike, to call capitalize. But we didn't do anything!

Scala automatically imports a few things for you into all the files; one of these is scala.Predef.
Predef has a whole lot of things in there; this one is relevant right now:

    implicit def augmentString(x : scala.Predef.String) : scala.collection.immutable.StringOps

StringOps is in [the scala source](https://github.com/scala/scala/blob/6ca8847eb5891fa610136c2c041cbad1298fb89c/src/library/scala/collection/immutable/StringOps.scala#L29)
, where we find out it's extends StringLike

    final class StringOps(override val repr: String) extends AnyVal with StringLike[String] {

So what does that implicit def mean?

An implicit conversion is a single parameter function, declared with the implicit keyword in front of it.
At any time a parameter or a method or an object of a method call would not compile as written,
 the compiler will attempt to use any implicit conversions
to make it match. The scoping of what you can put in implicit parameters is complicated. <- what? what is this sentence?

StringOps extends StringLike, so we can call all its methods on a string without having to do any manual wrapping. Convenient!

All this power comes with downsides. Conversions have to be put in scope, just like any
other implicit, and programmers have to know those conversions are available. Too many custom conversions make code harder to learn.
Another problem comes from using very wide conversions. Let's say that somewhere we defined classes that take a lot of options:

    case class Octopus(name:Option[String], tentacles:Option[Int], phoneNumber:Option[String])

If we always have the data, those Options are just noise, so a person who recently learned implicit conversions could write something like this!

    implicit def optionify[T](t:T):Option[T] = Option(t)

Which lets us make this call work:

    val name = "Angry Bob"
    val tentacles = 7
    val phone = "(888)-444-3333"

    val a = Octopus(name,tentacles,phone)

Sounds great, right? We never have to wrap any values anymore! What's the worst that could happen?

Wherever that implicit is in scope, any syntax error that could be fixed by wrapping anything into an option will try to
be fixed that way, whether it makes sense or not.

    val aList = ("a","b","c")
    val anInt = 42
    val something = Octopus("Angry Bob",7,"(888)-444-3333")

    aList.isEmpty
    anInt.isEmpty
    something.isEmpty

Only List has an isEmpty method, but the implicit conversion makes the other two work! That's not what we wanted with our
implicit conversion, but there it is. Add a few more implicits like that
to the same scope, and suddenly you might as well be working in a language without types: The compiler stops being useful.

If we want to use this kind of implicit conversion responsibly, we have to add the implicits very carefully, just for the
code than needs them

    object AutoOption {
      implicit def optionify[T](t:T):Option[T] = Option(t)
    }
  
    class PutsThingsIntoOptionsAllTheTime{
      import AutoOption._
  
      ... put code that uses the implicit conversion here _
  
    }
    
In general, views that convert anything to anything, or those that unexpectedly change the types of the class they extend,
will be confusing. An example of this that caused a lot of grief to scala programmers everywhere is how
scala automatically converts anything to a string when using + :

  implicit final class any2stringadd[A](private val self: A) extends AnyVal {
    def +(other: String): String = String.valueOf(self) + other
  }
  
 So this gives every class a + method that lets it concatenate to a String.
 
    Set(1,2,3) + "a gazebo" returns "Set(1, 2, 3)a gazebo"
    "a gazebo" + Set(1,2,3) returns a "gazeboSet(1, 2, 3)"
    Set("1","2","3") + "a gazebo" returns Set("1","2","3","a gazebo")

Those are pretty predictable, and not all that confusing. But then we have this [scala puzzler](http://scalapuzzlers.com/#pzzlr-040)

    List("1","2","3").toSet() + "a gazebo" returns falsea gazebo!

the parenthesis after toSet call a separate method than toSet, which returns false, so false + "a gazebo" is what we get.
And unlike our Option[T] implicit defined above, this one in every scala file you use.


There are two main cases where views are relatively safe and unsurprising:

1) When adding new functionality to a class, like with "fluttershy".capitalize. Notice, in the code above, how careful de library devs were
to make sure capitalize returns the type we started with. By not changing the return type, calling the method does not surprise us.

2)when trying to convert a class we cannot control to a subclass of another class we do control. 

Anything else is probably going to be confusing.

