module ArtifactArchiveSupport

import Pkg

export deterministic_archive_artifact

"""
    deterministic_archive_artifact(hash, destination)

Archive an installed Julia artifact and clear the gzip MTIME field. Julia's
artifact archiver writes a deterministic tar stream, but some Julia versions
put the current time in bytes 5–8 of the gzip header. The gzip checksum covers
only the uncompressed payload, so normalising this optional header field does
not modify or invalidate the tar payload.
"""
function deterministic_archive_artifact(hash, destination::AbstractString)
    Pkg.Artifacts.archive_artifact(hash, destination)
    open(destination, "r+") do io
        header = read(io, 10)
        length(header) == 10 || error("artifact archive has a truncated gzip header")
        header[1:3] == UInt8[0x1f, 0x8b, 0x08] ||
            error("artifact archiver did not produce a gzip stream")
        seek(io, 4)
        write(io, zeros(UInt8, 4))
    end
    return destination
end

end
