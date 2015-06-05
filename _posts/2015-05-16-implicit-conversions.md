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

The problem with this is that it's easy to abuse, and cause trouble with. Conversions have to be put in scope, just like any
other implicit, and then programmers have to know those conversions are available. Add too many of them, or make them
unnatural, and they increase the difficulty of working with your code more than they actually help.