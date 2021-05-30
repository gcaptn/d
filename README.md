# D

## Example usage

```lua
local key = "my-first-post"
local posts = D.getStore("posts")

posts:defaultTo({
  title = "Untitled",
  content = ""
})

posts:load(key)
  :andThen(function(entry)
    entry.data.title = "My first post"
    entry.data.content = "Hello world!"
    return posts:commit(key, entry)
  end)
  :andThen(function()
    print("done!")
  end)
  :catch(function(err)
    print("something went wrong:", err)
  end)
```
