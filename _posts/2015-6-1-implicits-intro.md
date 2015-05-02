---
layout: post
title: "Learn implicits: Scala reflection"
subtitle: "An intro to implicit parameters using Scala Reflection as an example"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implcits, scala, tutorials]
---

Implicits are arguably the most unique and misunderstood language of Scala.
The definitions of both [implicit parameters](http://docs.scala-lang.org/tutorials/tour/implicit-parameters.html)
 and [implicit conversions](http://docs.scala-lang.org/tutorials/tour/views.html) are relatively straightforward.
Figuring on when to use them, and the patterns they allow, is not so straightforward. 
The tricky part is that unlike other advanced features in the language, they are very hard to avoid:
Most major libraries in Scala, starting from the collection library, make heavy use of implicits, and that use is not invisible to the users of the library.

The simplest use of implicit parameters out there is probably in Scala reflection:
 ClassTags and TypeTags provide features that are beyond what Java offers. 
 Finally, a way to defeat erasure! The easiest and most common way of accessing a TypeTag for any given type is an implicit parameter.

{% highlight scala %}
val l = "A"::Nil 
def b[T](l:List[T])(implicit tag :TypeTag[T]) = tag.toString()
 println(b(l))
{% endhighlight %}

will print out
{% highlight scala %}
TypeTag[java.lang.String]
{% endhighlight %}

Great, we defeated erasure! But how did this wotk? How did that implicit TypeTag get there? Compiler magic!

The easiest way to think about implicits is that they are extra parameters to a function that can be populated
by the compiler instead of being passed manually. In the case of TypeTags and ClassTags,
we do not even have to do anything to make them work:the compiler will always be able to provide
an implicit TypeTag or ClassPath parameter for all real classes.

The context of the call to B knows that l is a List[String], so the compiler just fills in the implicit for us.
So once the compiler does implicit resolution, the code would look like this:

{% highlight scala %}
val l = "A"::Nil 
def b[T](l:List[T])(tag :TypeTag[T]) = tag.toString()
 println(b(l)(TypeTag[List[String]]))
{% endhighlight %}

This would not work if instead of the specific type, the calling code was using an generic type, for instance:

{% highlight scala %}
val l = "A"::Nil
 def b[T](l:List[T])(implicit tag :TypeTag[T]) = tag.toString()
 def intermediate[T](l:List[T]) = b(l)
 println(intermediate(l))
{% endhighlight %}

would not compile, because within intermediate, the compiler does not know the specific type T,
so we get a compilation error.

To make this work, itermediate needs to request the TypeTag itself, so that the compiler can pass the
implicit down to b:

{% highlight scala %}
val l = "A"::Nil
 def b[T](l:List[T])(implicit tag :TypeTag[T]) = tag.toString()
 def intermediate[T](l:List[T])(implicit tag :TypeTag[T]) = b(l)
 println(intermediate(l))
{% endhighlight %}

Now the compiler can resolve the implicit on the call to intermediate,
and then the compiler can keep passing the TypeTag it forward into b itself.

Without the implicits, it'd look like:

{% highlight scala %}
val l = "A"::Nil
 def b[T](l:List[T])(tag :TypeTag[T]) = tag.toString()
 def intermediate[T](l:List[T])(tag :TypeTag[T]) = b(l)(tag)
 println(intermediate(l)(TypeTag[List[String]])
{% endhighlight %}

This kind of pattern of carrying implicits over will happen with any other kind of implicit parameter:
If we are calling code that needs an implicit parameter, the implicit has to either be defined in the caller's scope,
or we have to make sure whoever is calling our scope provides it.

Comparing the code with implicits, and the one without, there is one major difference:
Anyone reading the top level code doesn't even have to know that a TypeTag is required. We pay a little
bit in compexity in the code that receives the implicit parameters, in exchange of simpler calling code.
No wonder implicit parameters are used all over the place in Scala!


