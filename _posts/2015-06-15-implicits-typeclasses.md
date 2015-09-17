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

Spray has pretty decent support for futures.

Show a plain complete: Future[T]
Show onComplete and onSuccess directives



Futures best practices:

Avoid nested future types: Future[Seq[Future[A]] is not easy to work with

Learn flatmap, Future.sequence and Future.traverse

Future[+T]{
    def map[S](T =>S) : Future[S]
    def flatmap[S](T =>Future[S]): Future[S]
    def recover[U >: T](pf : PartialFunction[scala.Throwable, U]) : Future[U] 
    def recoverWith[U >: T](pf : PartialFunction[scala.Throwable, scala.concurrent.Future[U]]) : Future[U]
}

object Future{
      def sequence[A, M[_] <: TraversableOnce[_]](in : M[Future[A]]) : Future[M[A]]
      def traverse[A, B, M[_] <: TraversableOnce[_]](in : M[A])(fn : A =>Future[B]) : Future[M[B]] 
}

Error handling:

When we only care about the failure of 
