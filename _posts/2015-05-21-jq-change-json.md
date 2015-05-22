If you need to parse through some JSON data at the command line, jq is here for you.
jq is its own programming language. There are tons of examples of how to use jq to extract data from JSON; 
this post shows how we use it to modify JSON.

Amazon Cloud Formation turns a JSON stack definition (plus a JSON configuration file)
 into a whole interconnected bunch of AWS resources. I frequently want to update my configuration. 
Using jq, I can do this from the command line. That means I can script it for automated tests.

The ACF configuration file looks like this:

    [{
       "ParameterKey": "Project",
       "ParameterValue": "<changeMe>"
     }, {
       "ParameterKey": "DockerInstanceType",
       "ParameterValue": "m3.medium"
     }]

The JSON is an array of objects, each with ParameterKey and ParameterValue. I want to change the ParameterValue for a particular ParameterKey. Here's the jq):

    cat config.json | jq 'map(if .ParameterKey == "Project" then . + {"ParameterValue":"jess-project"} else . end) > populated_config.json'

This says, "For each object in the array: check if ParameterKey is "Project". If so, combine that object with this other one (right-hand-side values win, so my ParameterValue overrides the existing one). If not, leave the object alone." Here, "." means "that thing you have."
The output file now contains

    [{
       "ParameterKey": "Project",
       "ParameterValue": "jess-project"
     }, {
       "ParameterKey": "DockerInstanceType",
       "ParameterValue": "m3.medium"
     }]

Hooray! The jq map function, combined with a conditional, let me change a particular value.

Since I do this often, I made a crude bash function and threw it in my .bash_profile so it will always be available:

    function populate-config() { jq "map(if .ParameterKey == \"$1\" then . + {\"ParameterValue\":\"$2\"} else . end)"; }

Now I can say

    cat config.json | populate-config Project jess-project | populate-config DockerInstanceType t2.micro > populated_config.json

Note that using the populate-config function over and over in the same pipe lets me change multiple values.

CAUTION:

The jq map function works on arrays. It's easy here, because the JSON happens to be an array. If I'm instead changing a value within an object, such as:

    {
      "honesty": "Apple Jack",
      "laughter": "Pinkie Pie",
      "loyalty": "Rainbow Dash"
    }

then I must convert the object's properties to an array, map over that array and then convert the array back into an object.


    cat ponies.json | jq 'to_entries | map(if .key == "honesty" then . + {"value":"Trixie"} else . end) | from_entries'

this gives:

    {
      "honesty": "Trixie",
      "laughter": "Pinkie Pie",
      "loyalty": "Rainbow Dash"
    }

That sneaky Trixie. Try running `cat ponies.json | jq to_entries` to see how this works.

FURTHER INVESTIGATION
You might ask, how do I modify arrays of objects nested in side other objects? If you find the answer, please ping us on twitter (@MonsantoCoEng) because I'm wondering this too.
