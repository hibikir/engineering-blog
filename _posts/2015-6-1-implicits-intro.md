---
layout: post
title: "Learn implicits: Scala reflection"
subtitle: "An intro to implicit parameters using Scala Reflection as an example"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implicits, scala, tutorials]
extra_css:
  - implicits-intro.css
---

Implicits are arguably <span class="banana">the most</span> unique and misunderstood language feature of Scala.
Unlike other advanced features in the language, they are very hard to avoid:
most major libraries in Scala, starting from Scala collections, make heavy use of implicits. That use is not invisible to the users of the library, especially when we choose to look at the code. The other tricky part about implicits is that there are so many ways to use them, each with a different reason and pattern.
They can't be fully explained in one coherent post.

This post explains one important use pattern on implicit parameters. It's a good place to start
 for understanding the how and why of Scala implicits.

Reflection lets us ask about type information at runtime.  
Java provides the .class method on all objects, 
but it is limited: type parameters are invisible at runtime.
 Scala's TypeTags can give us details about type parameters that
 the Java compiler would normally erase. 
 And what is the easiest and most common way of obtaining a TypeTag? An implicit parameter.

So for this exercise, we'll see 
<span class="get-inner-type">a little method</span>
 that takes a List, 
and returns the <span class="type-name">type name</span> 
of the {{ contents of the list | T }}.

<div class="highlight">
<pre>
import scala.reflect.runtime.universe._

def <span class="get-inner-type">getInnerType[<span class="T">T</span>]</span>(list:List[<span class="T">T</span>])(implicit tag:TypeTag[<span class="T">T</span>]) = tag.<span class="type-name">tpe.toString</span>
</pre>
</div>

Using that method, we can report on the inner type of a list:

{% highlight scala %}
  val stringList: List[String] = List("A")
  val stringName = getInnerType(stringList)
  println( s"a list of $stringName")
{% endhighlight %}

will print out
{% highlight scala %}
a list of java.lang.String
{% endhighlight %}

Great, we defeated erasure! But how did this work? How did that implicit TypeTag get there? Compiler magic!

The easiest way to think about implicit parameters is that they are extra parameters to a function that can be populated
by the compiler instead of being passed manually. In the case of TypeTags and ClassTags,
we do not have to do anything to make them work: the compiler will always be able to provide
an implicit TypeTag or ClassPath parameter for all real classes (as opposed to generics, which we'll cover in a minute).
* didn't we have to include that runtime universe thing ? That's why I have the import in the first ***

The context of the call to getInnerType knows that list is a List[String], so the compiler fills in the implicit for us.
The compiler fills the implicit as if we had called the method like this:

{% highlight scala %}
  import scala.reflect.runtime.universe._

  val stringList: List[String] = List("A")   
  val stringName = getInnerType(stringList)(typeTag(String))
  println( s"a list of $stringName")
{% endhighlight %}

That typeTag method is defined in the scala.reflect.runtime.universe object, 
and it triggers the same compiler magic as any request for an implicit TypeTag[T]. 
 TypeTag is special: instances of TypeTag are brought into being by Scala's compiler. This 
 contrasts with every other implicit parameter, supplied 
 (one way or another) by the programmer. That's why this is a great implicit to start with: 
see how to ask for it, before you learn how to supply it.

The compiler is able to pull-from-its-butt a TypeTag in this instance, because 
 it knows the fully qualified type of stringList. 
 When getInnerType is invoked, the compiler knows exactly what kind of List the parameter stringList is.
This would not work if instead of some specific type (String)
 the code calling getInnerType used a generic type, for instance:

{% highlight scala %}
  import scala.reflect.runtime.universe._

  def gratuitousIntermediateMethod[T](list:List[T]) = getInnerType(list)
{% endhighlight %}

{% highlight scala %}
  val stringList: List[String] = List("A") 
  val stringName = gratuitousIntermediateMethod(stringList)
  println( s"a list of $stringName")
{% endhighlight %}

This does not compile, because when the compiler tries to work 
on our gratuitous intermediate method, it does not know the specific type T represents,
so we get a compilation error.
 
{% highlight scala %}
 Error:(36, 83) No TypeTag available for T
     def gratuitousIntermediateMethod[T](list: List[T]) = getInnerType(list)
{% endhighlight %}                  

Scala's compiler can pull any type tag out of its butt except a mysterious type tag. 
Only the call sites of gratuitousIntermediateMethod can reveal the concrete type represented by T.
That's where the compiler can supply the TypeTag.

To make this work, the intermediate method needs to request the TypeTag itself, 
so that the compiler can pass the TypeTag down to getInnerType:

{% highlight scala %}
  import scala.reflect.runtime.universe._

  def gratuitousIntermediateMethod[T](list:List[T])(implicit tag :TypeTag[T]) = getInnerType(list)
{% endhighlight %}

{% highlight scala %}
  val stringList: List[String] = List("A") 
  val stringName = gratuitousIntermediateMethod(stringList)
  println( s"a list of $stringName")
{% endhighlight %}

{% highlight scala %}
a list of java.lang.String
{% endhighlight %}

We need parameters that carry the typeTag from where the type is concrete to where the typeTag is needed.**
This kind of pattern, carrying implicits over, happens with other kinds of implicit parameter:
Watch for future posts that reveal other examples of this implicit-handoff pattern.

Notice that the implicit parameter to getInnerType appears in a second parameter list. 
Implicit parameters are always separated from explicit parameters this way. We could declare
getInnerType with only one parameter list, all explicit parameters. Then the code would look like:

{% highlight scala %}
  import scala.reflect.runtime.universe._

  def getInnerType[T](list:List[T], tag :TypeTag[T]) = tag.tpe.toString
{% endhighlight %}

{% highlight scala %}
  val stringList: List[String] = List("A")
  val stringName = getInnerType(stringList, typeTag(String))
  println( s"a list of $stringName")
{% endhighlight %}

Comparing the code with implicits and the one without, there is one major difference:
The top level code doesn't have a trace of the TypeTag, 
so we do not have to know it is required. The compiler takes care of it. We pay a little
bit in complexity in the code that receives the implicit parameter,
 in exchange for simpler calling code.
The library author suffers once, while the library clients benefit many times.
No wonder implicit parameters are used all over the place in Scala!

