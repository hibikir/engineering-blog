---
layout: post
title: "Learn implicits: Scala reflection"
subtitle: "An intro to implicit parameters using Scala Reflection as an example"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implcits, scala, tutorials]
---

Implicits are arguably the most unique and misunderstood language feature of Scala.
The tricky part is that unlike other advanced features in the language, they are very hard to avoid:
most major libraries in Scala, starting from Scala collections, make heavy use of implicits. That use is not invisible to the users of the library, especially when we choose to look at the code. The other tricky part about implicits is that there are so many ways to use them, each with a different reason and pattern.
They can't be fully explained in one coherent post.

This post on implicit parameters explains one important use pattern. 

The simplest use of implicit parameters out there is probably in Scala reflection. Java's reflection provides the .class method on Object, which gives some runtime type information.
 Scala's ClassTags and TypeTags provide features that are beyond what Java offers. 
 The star feature for most people is that TypeTags can give us details about type parameters, at runtime, that
 the Java compiler would normally erase. 
 And what is the easiest and most common way of obtaining a TypeTag? An implicit parameter.

So for this first exercise, we'll see a little method that takes a list, and returns the type name of the contents of the list.

{% highlight scala %}
import scala.reflect.runtime.universe._

  val stringList = List("A")
  val intList = List(3,4,5)

  def getInnerType[T](list:List[T])(implicit tag :TypeTag[T]) = tag.tpe.toString

  val stringName = getInnerType(stringList)
  val intName = getInnerType(intList)
  println( s"$stringName, $intName")
{% endhighlight %}

will print out
{% highlight scala %}
java.lang.String, Int
{% endhighlight %}

Great, we defeated erasure! But how did this work? How did that implicit TypeTag get there? Compiler magic!

The easiest way to think about implicit parameters is that they are extra parameters to a function that can be populated
by the compiler instead of being passed manually. In the case of TypeTags and ClassTags,
we do not have to do anything to make them work: the compiler will always be able to provide
an implicit TypeTag or ClassPath parameter for all real classes (as opposed to generics, which we'll cover in a minute).
* didn't we have to include that runtime universe thing?***

The context of the call to getInnerType knows that list is a List[String], so the compiler fills in the implicit for us.
So once the compiler does implicit resolution, the code would look like this:

{% highlight scala %}
val stringList = List("A")
  val intList = List(3,4,5)
  def getInnerType[T](list:List[T])(implicit tag :TypeTag[T]) = tag.tpe.toString
  val stringName = getInnerType(stringList)(typeTag(String))
  val intName = getInnerType(intList)(typeTag(Int))
  println( s"$stringName, $intName")
{% endhighlight %}

** where is that typeTag method defined?**

This would not work if instead of some specific type, like String, the calling code was using a generic type, for instance:

{% highlight scala %}

  val stringList = List("A")
  val intList = List(3,4,5)

  def getInnerType[T](list:List[T])(implicit tag :TypeTag[T]) = tag.tpe.toString

  def gratuitousIntermediateMethod[T](list:List[T]) = getInnerType(list)

  val stringName = gratuitousIntermediateMethod(stringList)
  val intName = gratuitousIntermediateMethod(intList)
  println( s"$stringName, $intName")
{% endhighlight %}

This would not compile, because when the compiler tries to work on our gratuitous intermediate method, it does not know the specific type T,
so we get a compilation error. ** it can't call typetag(T) ? **

To make this work, the intermediate method needs to request the TypeTag itself, so that the compiler can pass the TypeTag all the way down
to getInnerType:

{% highlight scala %}
  val stringList = List("A")
  val intList = List(3,4,5)
  def getInnerType[T](list:List[T])(implicit tag :TypeTag[T]) = tag.tpe.toString
  def gratuitousIntermediateMethod[T](list:List[T])(implicit tag :TypeTag[T]) = getInnerType(list)
  val stringName = gratuitousIntermediateMethod(stringList)
  val intName = gratuitousIntermediateMethod(intList)
  println( s"$stringName, $intName")
{% endhighlight %}

** so basically, the compiler can come up with a typeTag anywhere for a concrete type, but not an abstract type. 
We need parameters that carry the typeTag from where the type is concrete to where the typeTag is needed.**
This kind of pattern of carrying implicits over will happen with any other kind of implicit parameter:
If we are calling code that needs an implicit parameter, the implicit has to either be defined in the caller's scope ** wait this is throwing me off.
Defined in the caller's scope?
Ah, there's something the example does not elucidate: is that runtime.universe import required at method definition, or method calling? The example has both in the same place so I can't tell!**
, or we have to make sure whoever is calling our scope provides it.

Without implicits, we could use a single parameter list, and the equivalent code looks like:

{% highlight scala %}
  val stringList = List("A")
  val intList = List(3,4,5)

  def getInnerType[T](list:List[T], tag :TypeTag[T]) = tag.tpe.toString

  def gratuitousIntermediateMethod[T](list:List[T], tag :TypeTag[T]) = getInnerType(list,tag)

  val stringName = gratuitousIntermediateMethod(stringList,typeTag(String))
  val intName = gratuitousIntermediateMethod(intList,typeTag(Int))
  println( s"$stringName, $intName")
{% endhighlight %}

Comparing the code with implicits and the one without, there is one major difference:
The top level code doesn't have a trace of the TypeTag, so we do not have to know it is required. We pay a little
bit in compexity in the code that receives the implicit parameters, in exchange for simpler calling code.
The library author suffers once, while the library clients benefit many times.
No wonder implicit parameters are used all over the place in Scala!

** I think maybe we should split the example into 2 parts. Specifically: devine getInnerType in an object in the top and never again. This separates calling from devining scope **


