---
layout: post
title: "Learn implicits: Scala Futures"
subtitle: "Exploring implicit parameters using Scala Futures"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implicits, scala, tutorials]
extra_css:
  - implicits-intro.css
---
Insert link to the previous post here

Intro bobber: This time we will cover futures, because they are useful, and we have to provide our own implicits

I will not cover what futures can, and cannot do for you, because it's complicated, and there are good sources out there

Very technical: http://docs.scala-lang.org/overviews/core/futures.html
Not so technical but cool: http://danielwestheide.com/blog/2013/01/09/the-neophytes-guide-to-scala-part-8-welcome-to-the-future.html

So futures are a way to work with non-blocking IO in a nice way. They are very nice in scala, because they are very
easy to use with higher order functions.

While they make things easy, and let people have to think of threads a lot less, they still use threads underneaht, just
hide them away, for the most part. We still have to care about them. This is abstracted into execution contexts.

Someone covered that in a nice video: https://www.youtube.com/watch?v=yhguOt863nw

An execution context is needed for any operation that might spawn a thread, just look at the signatures in Futures:

  def onSuccess[U](pf : scala.PartialFunction[T, U])(implicit executor : scala.concurrent.ExecutionContext) : scala.Unit 
  def onFailure[U](callback : scala.PartialFunction[scala.Throwable, U])(implicit executor : scala.concurrent.ExecutionContext) : scala.Unit 
  def onComplete[U](func : scala.Function1[scala.util.Try[T], U])(implicit executor : scala.concurrent.ExecutionContext) : scala.Unit
  def foreach[U](f : scala.Function1[T, U])(implicit executor : scala.concurrent.ExecutionContext) : scala.Unit = 
  def transform[S](s : scala.Function1[T, S], f : scala.Function1[scala.Throwable, scala.Throwable])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[S] = 
  def map[S](f : scala.Function1[T, S])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[S]
  def flatMap[S](f : scala.Function1[T, scala.concurrent.Future[S]])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[S] = 
  def filter(pred : scala.Function1[T, scala.Boolean])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[T] 
  def withFilter(p : scala.Function1[T, scala.Boolean])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[T]
  def collect[S](pf : scala.PartialFunction[T, S])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[S] 
  def recover[U >: T](pf : scala.PartialFunction[scala.Throwable, U])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[U] 
  def recoverWith[U >: T](pf : scala.PartialFunction[scala.Throwable, scala.concurrent.Future[U]])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[U]
  def andThen[U](pf : scala.PartialFunction[scala.util.Try[T], U])(implicit executor : scala.concurrent.ExecutionContext) : scala.concurrent.Future[T] = { /* compiled code */ }

 (We might want to cut a few)
 
 Show an exmaple of how repetitive code would be if we did not have implicits here.

 
 
So as Jess covered in her talk, the decisions on what execution context to use tend to be the same most of the time in an application
This makes them a great target for implicits, because we can set the implicit once in the header of a file, and it'd be used on the entire file
If you do not know any better, the global execution context is pretty nice. If you are working in Akka, you might want to use the Akka context
Maybe some talk about scoping.

In futures, we often get hit by the whole thing about having to carry an implicit with us in our own method with ECs.
If a function takes a future, chances are it'll do something with it that needs an EC, so we'll have to pass it implicitly.


But sometimes we get ourselves into trouble, when we have multiple implicits! 
If the compiler gets two implicits that have the same type, we have to either remove one, or be explicit.
So maybe we don't want to import the execution context at the top of the file, and either do it in a method, or be explicit

This also shows why it's nice that implicits are there, instead of having to, say, create a future with an EC,like you'd do in OO design
we can change the EC we use in different steps. For instance, if we wanted to limit our outbound connections to a resource.
EC that has 40 threads creates a future, and then we map it to something else, which will talk to that resource, using a more restrictive EC
Much easier to do that than the OO way.

Outro that is nice and happy about how the pain of implicits is pretty slight compared to the big benefits we get.