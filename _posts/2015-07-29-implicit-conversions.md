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

scala> val cap = s.{{ "capitalize" | sc: "capitalize" }}
cap: String = Fluttershy

scala> cap.getClass.getName
res2: String = java.lang.String
</pre>

<style scoped>
  .capitalize { color: #D907E8 }
  .implicitdef { color: #1AB955 }
</style>

so we have a plain Java String, and we {{ "capitalize" | sc: "capitalize" }}
 it. Seems simple. I just called a method on an object. 
Except java.lang.String does not have a {{ "capitalize" | sc: "capitalize" }}
 method! What sorcery is this?

![IntelliJ understands capitalize](/img/capitalize.png)

As IntelliJ tells us, the {{ "capitalize" | sc: "capitalize" }}
 method is a part of [StringLike](https://github.com/scala/scala/blob/6ca8847eb5891fa610136c2c041cbad1298fb89c/src/library/scala/collection/immutable/StringLike.scala#L141).

Somehow our String got converted into a StringLike, to call {{ "capitalize" | sc: "capitalize" }}
. But we didn't do anything!

Scala automatically imports `scala.Predef` everywhere. Among many other things, Predef contains:

<pre>
{{ "implicit def" | sc: "implicitdef" }} augmentString(x : String) : scala.collection.immutable.StringOps
</pre>

The return type of this method, [StringOps](https://github.com/scala/scala/blob/6ca8847eb5891fa610136c2c041cbad1298fb89c/src/library/scala/collection/immutable/StringOps.scala#L29),
has the StringLike trait which includes the {{ "capitalize" | sc: "capitalize" }}
 method.   

So what does that {{ "implicit def" | sc: "implicitdef" }} mean?

Any time we try to call a method that doesn't exist (or when a parameter doesn't match the expected type),
 the compiler attempts to use a view to make it match.
A view is a single-parameter function or constructor, declared with the {{ "implicit" | sc: "implicitdef" }} keyword in front of it. The  {{ "implicit" | sc: "implicitdef" }}  keyword tells the compiler
that it can use this function automatically, for as long as it is in scope.

It's almost as if Scala added methods without changing java.lang.String. No manual wrapping: it's almost invisible[1]. Sounds convenient!

All this power comes with downsides. If a programmer is not familiar with all the views in scope, the code is harder to interpret.
There's also the temptation to define very wide conversions. Everyone does it, and later regrets it.
Let's say that some classes take a lot of Options:

    case class Octopus(name : Option[String], tentacles : Option[Int], phoneNumber : Option[String])
    
    val a = Octopus(Some(name), Some(tentacles), Some(phone))

If we always have the data, those Options are just noise, so someone who recently learned views might write something like this:

<pre>
{{ "implicit def" | sc: "implicitdef" }} optionify[T](t : T):Option[T] = Option(t)
</pre>

Which lets this call work:

    val a = Octopus(name, tentacles, phone)

Sounds great, right? We never have to wrap any values anymore! What's the worst that could happen?

Wherever that implicit function is in scope, any syntax error that could be fixed by wrapping anything into an Option will be 
"fixed" that way, whether it makes sense or not.

    val aList = ("a","b","c")
    val anInt = 42
    val something = Octopus("Angry Bob",7,"(888)-444-3333")

    aList.isEmpty
    anInt.isEmpty
    something.isEmpty

List and Option define `isEmpty`. If you think you have a List, but you really have an Octopus, 
the compiler will use your view, give you an Option[Octopus], and `isEmpty` will compile! That's not what we wanted when we defined our view,
but there it is. Add a few more implicits like that to the same scope, and suddenly you might as well be working in a language without types:
 the compiler stops being useful.

To use this view responsibly,  add it to the scope very carefully, just for the
code than needs it:

<pre>
object AutoOption {
   {{ "implicit def" | sc: "implicitdef" }} def optionify[T](t:T):Option[T] = Option(t)
}

class PutsThingsIntoOptionsAllTheTime{
  import AutoOption._

  ... put code that uses the implicit conversion here ...

}
</pre>
    
In general, views that accept anything at all will be confusing. For example, Scala lets you call + on anything. Predef includes:

<pre>
{{ "implicit def" | sc: "implicitdef" }}  final class any2stringadd[A](private val self: A) extends AnyVal {
  def +(other: String): String = String.valueOf(self) + other
}
</pre>
  
 So this gives every class a + method that lets it concatenate to a String.

TODO: repl
    Set("1","2","3") + "a gazebo" returns Set("1","2","3","a gazebo")
    Set(1,2,3) + "a gazebo" returns "Set(1, 2, 3)a gazebo"
    "a gazebo" + Set(1,2,3) returns a "gazeboSet(1, 2, 3)"
    Set[Any](1,2,3) + "a gazebo" returns Set(1,2,3,"a gazebo")
    Some("gazebo") + 3 complains "Type mismatch, 3 is not a string"

If this isn't crazy enough for you, check out this [Scala puzzler](http://scalapuzzlers.com/#pzzlr-040).

This has annoyed so many people so much that there are plans to remove it in
a future version of Scala. If the language authors create troublesome views, the rest of us should take warning.

When creating views, aim to have the seamlessness of {{ "capitalize" | sc: "capitalize" }}. The view aims to be invisible. Notice that {{ "capitalize" | sc: "capitalize" }} returns a String; when we benefit from the view, we never see the intermediate StringOps type. Other bonus methods do the same:
 
<pre>
trait StringLike {
  def {{ "capitalize" | sc: "capitalize" }} : String
  def stripMargin(marginChar : Char) : String
  def stripPrefix(prefix : String)
}
</pre>  

Calling the method does not surprise us.
The one way the user can tell that we are using a custom implicit conversion is this subtle underline in IntelliJ:

![IntelliJ helps see implicits](/img/IntelliJUnderlinesImplicits.png)

 {{ "capitalize" | sc: "capitalize" }} is underlined because the method is added by a view.
The 42 is underlined because a Scala Int is converted to a Java Integer using another view defined in Predef[LINK].

While overly wide views in an overly wide scope can lead to confusion,
views are an invaluable way to extend
 class functionality with a strong type system, without a bunch of explicit wrapping. 


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
