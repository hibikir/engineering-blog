<Intro paragraph>

There are a few ways to do in-language dependency injection in Scala. One could use [reader monads](http://blog.originate.com/blog/2013/10/21/reader-monad-for-dependency-injection/)
or the [cake patter](http://www.cakesolutions.net/teamblogs/2011/12/19/cake-pattern-in-depth), but they have their own shortcomings.
Our favorite is Parfait, a pattern currently being used in the experimental scala compiler. Its implementation relies heavily on implicits.
