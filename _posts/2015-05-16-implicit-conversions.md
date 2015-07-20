---
layout: post
title: "Learn implicits: Views as class extensions"
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

   
(where scala.Predef.String is an alias for java.lang.String. <- maybe footnote this?) 
Somehow our String got converted into a StringLike, to call capitalize. But we didn't do anything!

Scala automatically imports `scala.Predef` everywhere. Among many other things, Predef contains:

    implicit def augmentString(x : scala.Predef.String) : scala.collection.immutable.StringOps

[StringOps](https://github.com/scala/scala/blob/6ca8847eb5891fa610136c2c041cbad1298fb89c/src/library/scala/collection/immutable/StringOps.scala#L29)
has the StringLike trait which includes the capitalize method.   

So what does that `implicit def` mean?

Any time a parameter doesn't match the expected type, or we try to call a method that doesn't exist,
 the compiler attempts to use a view to make it match.
A view is a single parameter function, declared with the implicit keyword in front of it. The implicit keyword tells the compiler
that as long as the function is in scope, the compiler can use it automatically.

It's almost as if Scala added methods without changing java.lang.String. No manual wrapping: it's almost invisible[1]. Sounds convenient!

All this power comes with downsides. If a programmer is not familiar with all the views in scope, the code is harder to learn.
There's also the temptation to define very wide conversions. Everyone does it, and later regrets it.
Let's say that some classes that take a lot of Options:

    case class Octopus(name : Option[String], tentacles : Option[Int], phoneNumber : Option[String])
    
    val a = Octopus(Some(name), Some(tentacles), Some(phone))

If we always have the data, those Options are just noise, so someone who recently learned views could write something like this:

    implicit def optionify[T](t : T):Option[T] = Option(t)

Which lets this call work:

    val name = "Angry Bob"
    val tentacles = 7
    val phone = "(888)-444-3333"

    val a = Octopus(name, tentacles, phone)

Sounds great, right? We never have to wrap any values anymore! What's the worst that could happen?

Wherever that implicit is in scope, any syntax error that could be fixed by wrapping anything into an Option will be 
"fixed" that way, whether it makes sense or not.

    val aList = ("a","b","c")
    val anInt = 42
    val something = Octopus("Angry Bob",7,"(888)-444-3333")

    aList.isEmpty
    anInt.isEmpty
    something.isEmpty

List and Option define `isEmpty`. If you think you have a List, but you really have an Octopus, 
the compiler will use your view, give you an Option[Octopus], and isEmpty will compile! That's not what we wanted when we defined our view,
but there it is. Add a few more implicits like that to the same scope, and suddenly you might as well be working in a language without types:
 the compiler stops being useful.

To use this view responsibly,  add it to the scope very carefully, just for the
code than needs it:

    object AutoOption {
      implicit def optionify[T](t:T):Option[T] = Option(t)
    }
  
    class PutsThingsIntoOptionsAllTheTime{
      import AutoOption._
  
      ... put code that uses the implicit conversion here ...
  
    }
    
In general, views that accept any type will be confusing. For example, Scala lets you call + on anything, as :

    implicit final class any2stringadd[A](private val self: A) extends AnyVal {
      def +(other: String): String = String.valueOf(self) + other
    }
  
 So this gives every class a + method that lets it concatenate to a String.

    Set("1","2","3") + "a gazebo" returns Set("1","2","3","a gazebo")
    Set(1,2,3) + "a gazebo" returns "Set(1, 2, 3)a gazebo"
    "a gazebo" + Set(1,2,3) returns a "gazeboSet(1, 2, 3)"
    Set[Any]1,2,3) + "a gazebo" returns Set(1,2,3,"a gazebo")

If this isn't crazy enough for you, check out this [scala puzzler](http://scalapuzzlers.com/#pzzlr-040).

This has annoyed Scala developers enough that there are plans to remove it in
a future version of Scala. If the language authors create troublesome views, the rest of us should take warning.

We should aim to have the seamlessness of capitalize in our own view. An important part is to have the methods in our view return the return type.
For instance, lets look at the signatures of some methods in StringLike.
 
    trait StringLike {
      def capitalize : String
      def stripMargin(marginChar : Char) : String
      def stripPrefix(prefix : String)
    }
  
All those methods exist in StringLike, but they do not return a StringLike, but a String. By returning the original type,
the view does its best to remain hidden: the code calling capitalize only sees Strings. Calling the method does not surprise us.
The one way the user can tell can tell that we are using a custom implicit conversion is IntelliJ.

![IntelliJ helps see implicits](/img/IntelliJUnderlinesImplicits.png)

The 42 is underlined because Scala is converted a Scala int to a java int using a view, also defined in Predef.

Despite the possible surprises confusion, views are invaluable as a way to extend
 class functionality while still maintaining a strong type system, and without requiring explicit wrapping.


//this is another pos

2)when trying to convert a class we cannot control to a subclass of another class we do control. For instance. Imagine that
we have a small crass hierarchy:

trait fruit{
    def vitamins: Set(String)
    def color: String
}

final class StringOps(override val repr: String) extends AnyVal with StringLike[String] {


object Banana(val vitamins: Set("B6","C"),val color("Yellow")) extends Fruit
object GrannySmithApple(val vitamins: Set("C"),val color("Green")) extends Fruit

and then we are using a library that has a Tomato:

class Tomato(val variety:String,val color:String) {

val vitamins: List("C","K","B6","E")
)

Whoever wrote that class did not realize that a Tomato is a Fruit! In Java, we'd build a TomatoWrapper. In scala, we can write
an implicit conversion:

implicit def TomatoIsAFruit(t:Tomato) = new Tomato extends Fruit{val vitamins = t.vitamins.toSet; val color = t.color}

A Tomato is still a tomato, 


Any other uses are probably dangerous.
