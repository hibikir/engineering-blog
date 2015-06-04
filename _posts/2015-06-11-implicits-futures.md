---
layout: post
title: "Learn implicits: Scala Futures"
subtitle: "Exploring implicit parameters using Scala Futures"
header-img: "img/mon-field_rows.jpg"
author: "Jorge Montero"
tags: [implicits, scala, tutorials, futures]
extra_css:
  - implicits-intro.css
---

<style scoped>
  .raw { color: #D907E8 }
  .futureMethods { color: #19BEFF }
  .ec {color: #E80D0C }
  .implicit {color: #1ab955 }
  .implicitDecl {color: #FF9C00 }
</style>

Implicits are difficult to understand because they have many different uses.
In [an earlier post](http://engineering.monsanto.com/2015/05/14/implicits-intro/),
we looked at implicit parameters and type tags.
Now, we'll take a look at another usage pattern every Scala programmer sees: 
implicits as an alternative to passing the same argument over and over. Scala Futures use implicit parameters in this way.
 
There is [much](http://danielwestheide.com/blog/2013/01/09/the-neophytes-guide-to-scala-part-8-welcome-to-the-future.html) 
to say about [futures](http://docs.scala-lang.org/overviews/core/futures.html) elsewhere. The gist of it is that a Future contains a value that may
or may not have been computed yet.
Futures let us spin off work into other threads, add more operations that should be performed on the result,
define what should happen after failure, and (if we really must) wait for the operation to complete.

Everything we do asynchronously happens on some other thread. 
Creating a future, adding operations after success, adding failure handling -- in each case, we need to tell it what thread to run on. 
The futures library lets us specify this using implicit parameters.

For illustration, let's define some data types and a fake Data Access Object with the following operations:

<div class="highlight"><pre><code class="language-scala" data-lang="scala">case class Employee(id:Int, name:String)
case class Role(name:String, department :String)
case class EmployeeWithRole(id :Int, name :String, role :Role)

trait EmployeeGrabberBabber {
  def {{"rawEmployee"| sc: "raw"}}(id :Int) :Employee
  def {{"rawRole"| sc: "raw"}}(e :Employee) :Role
  def {{"employee"| sc: "futureMethods"}}(id: Int)({{"implicit e :ExecutionContext"| sc: "implicit"}}) :Future[Employee]
  def {{"role"| sc: "futureMethods"}}(employee :Employee)({{"implicit e :ExecutionContext"| sc: "implicit"}}) :Future[Role]
}</code></pre></div>
I have [an implementation](https://gist.github.com/hibikir/5793ffe80c545f9971d1) for that trait, but it's not that important.

{{"The first two methods"| sc: "raw"}} do synchronous IO: Whenever we call them, our thread will patiently wait until we get the requested information, leaving our thread blocked.
{{"The second pair"| sc: "futureMethods"}} use Futures: {{"employee"| sc: "futureMethods"}}
 returns a Future[Employee], which will eventually provide an Employee, or error out.
  We do not wait for the operation to complete before returning; the caller gets the power of deciding whether to wait,
   whether to attach more actions, whether to handle errors.

With {{"the first set of methods"| sc: "raw"}}, if we wanted to get an Employee, and then get their Role, and then combine that into an EmployeeWithRole:
<div class="highlight"><pre><code class="language-scala" data-lang="scala">val employee = grabber.{{"rawEmployee"| sc: "raw"}}(100)
val role = grabber.{{"rawRole"| sc: "raw"}}(employee)
val bigEmployee = EmployeeWithRole(employee.id,employee.name,role)</code></pre></div>

This is procedural programming. It holds up the calling thread until the entire calculation is made. You probably don't want to do this in a web application 
or in an event thread in a native UI toolkit.

In contrast, the {{"asynchronous methods"| sc: "futureMethods"}} return instantly. We can keep right on defining what to do with the value -- inside the context of the Future.

<div class="highlight"><pre><code class="language-scala" data-lang="scala">val bigEmployee: Future[EmployeeWithRole] =
  grabber.{{"employee"| sc: "futureMethods"}}(100).flatMap { e =>
    grabber.{{"role"| sc: "futureMethods"}}(e).map { r =>
      EmployeeWithRole(e.id,e.name,r)
    }
  }</code></pre></div>

This code puts both operations together without blocking.

Except, the code above does not work on its own. Remember those {{"implicit parameters"| sc: "implicit"}} defined above in EmployeeGrabberBabber?

<div class="highlight"><pre><code class="language-scala" data-lang="scala">def {{"employee"| sc: "futureMethods"}}(id :Int)({{"implicit e :ExecutionContext"| sc: "implicit"}}) :Future[Employee]
def {{"role"| sc: "futureMethods"}}(employee :Employee)({{"implicit e: ExecutionContext"| sc: "implicit"}}) : Future[Role]
</code></pre></div> 
  
We did not define them, as the compiler helpfully reminds us.
<div class="highlight"><pre><code>Error: Cannot find an {{"implicit ExecutionContext"| sc: "implicit"}}. You might pass
an (implicit ec: ExecutionContext) parameter to your method
or import scala.concurrent.ExecutionContext.Implicits.global.
    grabber.{{"employee"| sc: "futureMethods"}}(100).flatMap { e =>
                    ^</code></pre></div>

That's a useful error message! While we could just add the import, we'd not learn much from doing that, so let's dig deeper.

Creating a Future starts an asynchronous operation on another thread. The ExecutionContext provides the thread pool that Future will use.
Different execution contexts wrap different thread pools, with different properties.
The one that the errors suggest, Scala's [global execution context](http://blog.jessitron.com/2014/02/scala-global-executioncontext-makes.html), suits us for now.

{{"The Future-creating methods"| sc: "futureMethods"}} declare two parameter lists. We can be perfectly clear about which ExecutionContext each should use by passing it explicitly:
<div class="highlight"><pre><code class="language-scala" data-lang="scala">val {{"ec"| sc: "ec"}} =  scala.concurrent.ExecutionContext.Implicits.global
val bigEmployee: Future[EmployeeWithRole] =
  grabber.{{"employee"| sc: "futureMethods"}}(100)({{"ec"| sc: "ec"}}).flatMap { e =>
    grabber.{{"role"| sc: "futureMethods"}}(e)({{"ec"| sc: "ec"}}).map { r =>
      EmployeeWithRole(e.id,e.name,r)
    }
  }</code></pre></div>

But that doesn't work either!
<div class="highlight"><pre><code class="language-scala" data-lang="scala">
Error: Cannot find an {{"implicit ExecutionContext"| sc: "implicit"}}. You might pass
an (implicit ec: ExecutionContext) parameter to your method
or import scala.concurrent.ExecutionContext.Implicits.global.
      grabber.{{"employee"| sc: "futureMethods"}}(100)({{"ec"| sc: "ec"}}).flatMap { e =>
                                      ^</code></pre></div>       
The flatmap method on Future also wants an ExecutionContext! We gave that Future another operation to perform, and it needs a thread pool to run that on. 
Future.map has the same problem, so pass the ExecutionContext there, too. This is getting tedious.

<div class="highlight"><pre><code class="language-scala" data-lang="json">val {{"ec"| sc: "ec"}} =  scala.concurrent.ExecutionContext.Implicits.global
val bigEmployee: Future[EmployeeWithRole] =
  grabber.{{"employee"| sc: "futureMethods"}}(100)({{"ec"| sc: "ec"}}).flatMap { e =>
    grabber.{{"role"| sc: "futureMethods"}}(e)({{"ec"| sc: "ec"}}).map { r =>
      EmployeeWithRole(e.id,e.name,r)
    }({{"ec"| sc: "ec"}})
  }({{"ec"| sc: "ec"}})</code></pre></div>

So now it's happy, and it's very clear which ExecutionContext every operation runs in. 
But I'm not happy, because it's repetitive and cluttered. It gets even more cluttered,
 the more things we call on a Future. Just look at these signatures from the [Future API](http://www.scala-lang.org/api/2.10.1/index.html#scala.concurrent.Future):
<div class="highlight"><pre><code>    def onSuccess\[U\](pf : PartialFunction[T, U])({{"implicit executor : ExecutionContext"| sc: "implicit"}})
    def onFailure\[U\](callback : PartialFunction[Throwable, U])({{"implicit executor : ExecutionContext"| sc: "implicit"}}) 
    def onComplete\[U\](func : Try[T] => U)({{"implicit executor : ExecutionContext"| sc: "implicit"}})
    def foreach\[U\](f : T => U)({{"implicit executor : ExecutionContext"| sc: "implicit"}}) 
    def transform\[S\](s : T => S, f : Throwable => Throwable)({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[S] 
    def map\[S\](f : T => S)({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[S]
    def flatMap\[S\](f : T => Future[S])({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[S] 
    def filter(pred : T => Boolean)({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[T] 
    def withFilter(p : T => Boolean)({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[T]
    def collect\[S\](pf : T => S)({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[S] 
    def recover\[U >: T\](pf : PartialFunction[Throwable, U])({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[U] 
    def recoverWith\[U >: T\](pf : PartialFunction[Throwable, Future[U]])({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[U]
    def andThen\[U\](pf : PartialFunction[Try[T], U])({{"implicit executor : ExecutionContext"| sc: "implicit"}}) : Future[T]</code></pre></div>

{{"ExecutionContexts"| sc: "implicit"}} everywhere. They're important, and sometimes we need to be specific about where each operation should run,
 but the common case is that they can all run in the same pool. It is tedious, cluttered, and error-prone to repeat
that same bit of information over and over.

When a function has multiple parameter lists, Scala permits the {{"implicit"| sc: "implicit"}} keyword at the beginning of the last parameter list.
<div class="highlight"><pre><code>  def {{"employee"| sc: "futureMethods"}}(id:Int)({{"implicit e:ExecutionContext"| sc: "implicit"}}) :Future[Employee]</code></pre></div>

This instructs the Scala compiler to pull those arguments out of its magic hat, instead of requiring them to be passed each time. 

![Trixie's magic hat](/img/magic_hat.png)

If it's ok to use all those threads in the same pool, 
then we can supply the execution context {{"implicitly"|sc: "implicitDecl"}}, which puts it in the magic hat:
<div class="highlight"><pre><code class="language-scala" data-lang="scala">{{"implicit val"|sc: "implicitDecl"}} {{"ec"| sc: "ec"}}: ExecutionContext = scala.concurrent.ExecutionContext.Implicits.global
val bigEmployee: Future[EmployeeWithRole] =
  grabber.{{"employee"| sc: "futureMethods"}}(100).flatMap { e =>
    grabber.{{"role"| sc: "futureMethods"}}(e).map { r =>
      EmployeeWithRole(e.id,e.name,r) 
    }
  }
</code></pre></div>

Here, the {{"implicit"| sc: "implicitDecl"}} keyword is serving a different (but related) purpose than it did in the parameter list. 
The {{"implicit val"| sc: "implicitDecl"}} goes into the compiler's magic hat for as long as that value is in scope.
 The compiler can use it anywhere it needs to supply an {{"implicit parameter"| sc: "implicit"}} of type ExecutionContext, over and over.

This lets us use for-comprehensions too, which take the place of flatmap and map:
 <div class="highlight"><pre><code class="language-scala" data-lang="scala">{{"implicit val"| sc: "implicitDecl"}} {{"ec"| sc: "ec"}} =  scala.concurrent.ExecutionContext.Implicits.global
val employeeWithRole = for { employee <- grabber.{{"employee"| sc: "futureMethods"}}(200L)
                            role <- grabber.{{"role"| sc: "futureMethods"}}(employee) } 
                            yield EmployeeWithRole(employee.id,employee.name,role)   </code></pre></div>  

Much cleaner.

This implicit-parameter-supplying feature only works if there is exactly one
{{"value"| sc: "implicitDecl"}} of the needed type in the compiler's magic hat when the method that
declares the {{"implicit parameter"| sc: "implicit"}} is called.  If none are available, you get that
"Cannot find an implicit" compile error. If more than one are available,
you get an "ambiguous implicit" error

Of the many ways to get values into the magic hat, three make sense for the
ExecutionContext. The simplest is to declare an {{"implicit val"| sc: "implicitDecl"}}, as above.  It
stays in the magic hat as long as the val is in scope.  This is common inside an Akka actor:

<div class="highlight"><pre><code>class SomeActor extends Actor {
  {{"implicit val"| sc: "implicitDecl"}} ec: ExecutionContext = context.dispatcher
}</code></pre></div>

Another is to declare an {{"implicit parameter"| sc: "implicit"}}: that value is in the magic hat
inside the method. This is good practice, because it lets the caller decide
what to use. For example, this {{"e"| sc: "implicit"}} is available to the Future constructor:

<div class="highlight"><pre><code>  def {{"employee"| sc: "futureMethods"}}(id:Int)({{"implicit e :ExecutionContext"| sc: "implicit"}}) :Future[Employee] = Future{...}</code></pre></div>

Finally, the most common way to punt on the selection of the execution context is to 
import an {{"implicit val"| sc: "implicitDecl"}} in file scope:

    import scala.concurrent.ExecutionContext.Implicits.global

Inside [scala.concurrent.ExecutionContext.Implicits](https://github.com/scala/scala/blob/2.11.x/src/library/scala/concurrent/ExecutionContext.scala#L130), {{"global"| sc: "implicitDecl"}} 
is an {{"implicit val"| sc: "implicitDecl"}}, so into the magic hat it goes. Adding this to the top of the file 
chooses the default execution context for asynchronous operations.

Any way you do it, one {{"implicit value"| sc: "implicitDecl"}} declaration saves repetition, 
providing a default per scope while allowing an override at each function call. 
The authors of the Future library put the ExecutionContext into an {{"implicit parameter"| sc: "implicit"}} for this reason:
it's common to repeat the same value, common to pass it down through various methods,
and essential that it be explicitly passed sometimes, at the caller's discretion.
In this way, Scala lets library designers keep the interface clean and flexible at the same time. 







