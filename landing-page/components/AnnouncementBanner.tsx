'use client'

import Link from 'next/link'
import { HiX } from 'react-icons/hi'
import { useState } from 'react'

const AnnouncementBanner = () => {
  const [isVisible, setIsVisible] = useState(true)

  if (!isVisible) return null

  return (
    <div className="bg-gradient-to-r from-pink via-pink/90 to-pink text-white py-3 px-4 relative">
      <div className="container-custom">
        <div className="flex items-center justify-center gap-2 text-center">
          <span className="text-sm md:text-base font-bold">
            🎉 Founding Customer Offer: 40% Off All Plans - Limited to First 10 Companies
          </span>
          <Link
            href="#pricing"
            className="hidden sm:inline-block bg-white text-pink px-4 py-1 rounded-full text-sm font-bold hover:bg-light transition-colors ml-2"
          >
            View Pricing
          </Link>
        </div>
      </div>
      <button
        onClick={() => setIsVisible(false)}
        className="absolute right-4 top-1/2 -translate-y-1/2 text-white hover:text-light transition-colors"
      >
        <HiX size={20} />
      </button>
    </div>
  )
}

export default AnnouncementBanner
