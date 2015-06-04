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
Implicits are difficult to understand because they have many different uses.
Last time, we looked at implicit parameters and type tags. Now, we'll take a look at another use of implicit parameters that every Scala
programmer sees: implicits as an alternative to passing the same argument over and over. Scala Futures use implicit parameters in this way.
 
There is [much](http://danielwestheide.com/blog/2013/01/09/the-neophytes-guide-to-scala-part-8-welcome-to-the-future.html) to say about [futures](http://docs.scala-lang.org/overviews/core/futures.html); here, 
I will not explain them deeply. The gist of it is that
a Future represents a value that may or may not have been computed yet. Futures let us spin off work into other threads, then add more operations that should be performed on the result, define what should happen after failure, and (if we really must) wait for the operation to complete.

Everything we do asynchronously happens on some thread. Creating a future, adding operations after success, adding failure handling -- in each case, we need to tell it what thread to run on. 
Implicits are handy in cases like this.

For illustration, let's define some fake Data Access Object with the following operations:

case class Employee(id:Long, name:String)
case class Role(name:String,department:String)
case class EmployeeWithRole(id:Long,name:String,role:Role)

trait EmployeeGrabberBabber{
  def rawEmployee(id:Long) :Employee
  def rawRole(e:Employee)  :Role
  def employee(id:Long)(implicit e:ExecutionContext) :Future[Employee]
  def role(employee:Employee)(implicit e:ExecutionContext) : Future[Long]
}

I have an implementation for that trait, but it's not really that important. you can find it hereLINK.

The first two methods do synchronous IO: Whenever we call them, our thread will patiently wait until we get the requested information, leaving our thread blocked.
The second pair use Futures: employee returns a Future[Employee], that will eventually become an Employee, or error out. We do not wait for the operation to complete before returning; the caller gets the power of deciding whether to wait, whether to attach more actions or error handling.

with the first set of methods, if we wanted to get an Employee, and then get their Role, and then print it out, we'd do something like:

  val employee = grabber.rawEmployee(100L)
  val role = grabber.rawRole(employee)
  val bigEmployee = EmployeeWithRole(employee.id,employee.name,role)

This is procedural programming. It holds up the calling thread until the entire calculation is made. Be careful about doing this in a web application or an event thread in a native UI toolkit.

The asynchronous methods return instantly, and we can keep right on defining what to do with the value once the Future has it.

val role :Future[Role] = grabber.employee(200L).flatMap(e => grabber.role(e)) 

Returns instantly, and letting the code that puts both operations together do no blocking.

Except, the code above, as written, would not work. Remember those implicit parameters defined above in EmployeeGrabberBabber?

  def employee(id:Long)(implicit e:ExecutionContext) :Future[Employee]
  def role(employee:Employee)(implicit e:ExecutionContext) : Future[Long]
  
We did not define them, as the compiler helpfully reminds us.

Error: Cannot find an implicit ExecutionContext. You might pass
an (implicit ec: ExecutionContext) parameter to your method
or import scala.concurrent.ExecutionContext.Implicits.global.
  val future = grabber.employee(200L).flatMap(employee => grabber.role(employee))
                               ^
That's a pretty good error! 
An execution context allows us to set yp asynchronous operations. It usually does that by delegating to a thread pool.
Different execution contexts will wrap different thread pools, with different properties. The one that the errors uggest,
Scala's global execution context, is a good default pool that will suit us for now.

So let's try to pass the parameter explicitly, and do the same to the call to role, a little bit further:

  val ec =  scala.concurrent.ExecutionContext.Implicits.global
  val role :Future[Role] = grabber.employee(200L)(ec).flatMap(e => grabber.role(e)(ec)) 

But that doesn't work either!

Error: Cannot find an implicit ExecutionContext. You might pass
an (implicit ec: ExecutionContext) parameter to your method
or import scala.concurrent.ExecutionContext.Implicits.global.
  val future = grabber.employee(200L)(ec).flatMap(employee => grabber.role(employee)(ec))
                                                 ^
FlatMap also wants an execution context! this is getting tedious.

  val ec =  scala.concurrent.ExecutionContext.Implicits.global
  val role :Future[Role] = grabber.employee(200L)(ec).flatMap(e => grabber.role(e)(ec))(ec) 

So now it's happy. But why did we need that implicit? Let's take a quick look at the signatures in Future:

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

Thats a lot of methods that needs an execution context! Any time we care about a Future's output, that code needs to run a thread somewhere, 
and that's what we define with an execution context.

If it's ok to use all those threads in the same pool, then we can just pass the execution context implicitly:


  implicit val ec =  scala.concurrent.ExecutionContext.Implicits.global
  val role :Future[Role] = grabber.employee(200L).flatMap(e => grabber.role(e)) 

and this also lets us use for comprehensions too, which allow us to do more complex work cleanly:

  implicit val ec =  scala.concurrent.ExecutionContext.Implicits.global
  val EmployeWithRole = for (employee <- grabber.employee(200L);
                        role <- grabber.role(employee)) yield EmployeeWithRole(employee.id,employee.name,role)

which would look far more convoluted using map and flatmap:

grabber.employee(200L)
    .flatMap(employee => grabber.role(employee).map(role => EmployeeWithRole(employee.id,employee.name,role)))

Now, while futures are making asynchronous work look easy, they do not allows us to really stop caring about threads and thread pools

Someone covered that in a nice video: https://www.youtube.com/watch?v=yhguOt863nw
 
So as Jess covered in her talk, the decisions on what execution contexts to use are often done application wide.
This makes them a great target for implicits, because we can set the implicits in one place, and let them percolate all the way to the code doing the IO.
This is done using the implicit passing pattern we saw in part 1.

So, what execution context to use?
If you do not know any better, the global execution context is a pretty safe choice. You might want more control in a few cases,
For instance, Execution contexts that will do blocking IO (Like talking to a DB) probably want to run in a fixed thread pool.
If you are working in Akka, you might want to use the akka dispatcher. Play has a different default context for user threads too.

But sometimes we get ourselves into trouble, when we have multiple implicits! 
If the compiler gets two implicits that have the same type, we have to either remove one, or be explicit.
So maybe we don't want to import the execution context at the top of the file, and either do it in a method, or be explicit

This also shows why it's nice that implicits are there, instead of having to, say, create a future with an EC,like you'd do in OO design
we can change the EC we use in different steps. For instance, if we wanted to limit our outbound connections to a resource.
EC that has 40 threads creates a future, and then we map it to something else, which will talk to that resource, using a more restrictive EC
Much easier to do that than the OO way.

Outro that is nice and happy about how the pain of implicits is pretty slight compared to the big benefits we get.

This The error that we get when we are missing the implicit:
Error:(13, 16) Cannot find an implicit ExecutionContext. You might pass
an (implicit ec: ExecutionContext) parameter to your method
or import scala.concurrent.ExecutionContext.Implicits.global.
