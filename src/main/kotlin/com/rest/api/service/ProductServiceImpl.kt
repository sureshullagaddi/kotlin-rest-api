package com.rest.api.service

import com.rest.api.entity.Product
import com.rest.api.repository.ProductRepository
import org.springframework.stereotype.Service
import java.time.LocalDateTime


@Service
class ProductServiceImpl(
    private val productRepository: ProductRepository
) : ProductService {
    override fun getAllProducts(): List<Product> = productRepository.findAll()
    override fun getProductById(id: Long): Product? = productRepository.findById(id).orElse(null)
    override fun createProduct(product: Product): Product = productRepository.save(product)
    override fun updateProduct(id: Long, product: Product): Product? {
        val existingProduct = productRepository.findById(id).orElse(null) ?: return null
        val updated = existingProduct.copy(name = product.name, price = product.price)
        return productRepository.save(updated)
    }
    override fun deleteProduct(id: Long) = productRepository.deleteById(id)
    override fun getProductByName(name: String): Product? = productRepository.findByName(name)
}
